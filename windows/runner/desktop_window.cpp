#include "desktop_window.h"
#include "desktop_telemetry.h"
#include "resource.h"
#include <windows.h>
#include <objidl.h>
#include <gdiplus.h>
#include <shellapi.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <algorithm>
#include <cmath>
#include <memory>
#include <string>
#include <vector>
#include <tuple>
namespace {
using Value=flutter::EncodableValue;using Map=flutter::EncodableMap;
std::unique_ptr<flutter::MethodChannel<Value>> channel;
HWND window=nullptr,desktop_host=nullptr;ULONG_PTR graphics_token=0;DesktopTelemetry& telemetry=SharedDesktopTelemetry();
IStream* image_stream=nullptr;std::unique_ptr<Gdiplus::Bitmap> image;
HDC buffer_dc=nullptr;HBITMAP buffer_bitmap=nullptr,buffer_old=nullptr;int buffer_w=0,buffer_h=0;void* buffer_bits=nullptr;
std::wstring title=L"等待播放",artist,lyric,translation;int edge=4,style=0,graph_style=0;
double scale=1,opacity=.94,extent=1,offset=.5,progress=0,graph_extent=.35,angle=0;
bool show_cover=true,show_lyrics=true,show_graph=true,show_progress=true,show_stats=true,playing=false,visible=false,tray=false;
bool transparent_background=true,show_title=true,show_artist=true,show_translation=true;
bool stat_items[7]={true,true,true,true,false,false,false};double font_scale=1,progress_thickness=4,progress_thumb=5;bool auto_font=true;
struct Box{double x,y,w,h;};
Box layout[5]={{.06,.18,.20,.40},{.32,.22,.61,.33},{.32,.62,.61,.28},{.06,.04,.88,.09},{.04,.94,.92,.06}};
constexpr UINT tray_message=WM_APP+77;constexpr int hotkey_id=701;
const Value* Field(const Map& m,const char* key){const auto it=m.find(Value(key));return it==m.end()?nullptr:&it->second;}
double Number(const Map& m,const char* key,double fallback){const auto* v=Field(m,key);if(!v)return fallback;if(auto* n=std::get_if<double>(v))return std::isfinite(*n)?*n:fallback;if(auto* n=std::get_if<int32_t>(v))return *n;if(auto* n=std::get_if<int64_t>(v))return static_cast<double>(*n);return fallback;}
bool Flag(const Map& m,const char* key,bool fallback){const auto* v=Field(m,key);const auto* b=v?std::get_if<bool>(v):nullptr;return b?*b:fallback;}
std::wstring Text(const Map& m,const char* key){const auto* v=Field(m,key);const auto* s=v?std::get_if<std::string>(v):nullptr;if(!s||s->empty())return L"";const int n=MultiByteToWideChar(CP_UTF8,0,s->data(),static_cast<int>(s->size()),nullptr,0);std::wstring out(n,0);MultiByteToWideChar(CP_UTF8,0,s->data(),static_cast<int>(s->size()),out.data(),n);return out;}
void ReleaseCover(){image.reset();if(image_stream){image_stream->Release();image_stream=nullptr;}}
void ReleaseBuffer(){if(buffer_dc){SelectObject(buffer_dc,buffer_old);DeleteObject(buffer_bitmap);DeleteDC(buffer_dc);buffer_dc=nullptr;buffer_bitmap=nullptr;buffer_old=nullptr;}}
Gdiplus::Color Accent(){const Gdiplus::ARGB colors[]={0xff8be7e2,0xffdab0ff,0xffffcf85,0xffb6ff76,0xfff5f5f5,0xffff8ba5};return Gdiplus::Color(colors[std::clamp(style,0,5)]);}
BOOL CALLBACK FindDesktopHost(HWND candidate,LPARAM out){
  if(FindWindowExW(candidate,nullptr,L"SHELLDLL_DefView",nullptr)){
    HWND worker=FindWindowExW(nullptr,candidate,L"WorkerW",nullptr);
    if(worker&&!FindWindowExW(worker,nullptr,L"SHELLDLL_DefView",nullptr)){
      *reinterpret_cast<HWND*>(out)=worker;return FALSE;
    }
  }
  return TRUE;
}
bool AttachDesktop(){
  if(!window)return false;
  if(IsWindow(desktop_host)&&GetParent(window)==desktop_host)return true;
  HWND progman=FindWindowW(L"Progman",nullptr);if(!progman)return false;
  DWORD_PTR ignored=0;
  // Explorer hosts differ by Windows version. Do not fall back to topmost.
  SendMessageTimeoutW(progman,0x052C,0xD,0,SMTO_ABORTIFHUNG,500,&ignored);
  SendMessageTimeoutW(progman,0x052C,0xD,1,SMTO_ABORTIFHUNG,500,&ignored);
  desktop_host=FindWindowExW(progman,nullptr,L"WorkerW",nullptr);
  if(!desktop_host)EnumWindows(FindDesktopHost,reinterpret_cast<LPARAM>(&desktop_host));
  if(!desktop_host&&FindWindowExW(progman,nullptr,L"SHELLDLL_DefView",nullptr))desktop_host=progman;
  if(!IsWindow(desktop_host))return false;
  SetWindowLongPtrW(window,GWL_STYLE,(GetWindowLongPtrW(window,GWL_STYLE)&~WS_POPUP)|WS_CHILD);
  SetLastError(0);HWND previous=SetParent(window,desktop_host);
  if(!previous&&GetLastError()!=0){desktop_host=nullptr;return false;}
  SetWindowPos(window,HWND_BOTTOM,0,0,0,0,SWP_NOMOVE|SWP_NOSIZE|SWP_NOACTIVATE|SWP_FRAMECHANGED);
  return true;
}
void Position(){if(!window||!IsWindow(desktop_host))return;MONITORINFO monitor{sizeof(MONITORINFO)};GetMonitorInfo(MonitorFromWindow(window,MONITOR_DEFAULTTONEAREST),&monitor);const RECT r=monitor.rcWork;const int sw=r.right-r.left,sh=r.bottom-r.top;const double dpi=GetDpiForWindow(window)/96.;
  const bool vertical=edge==2||edge==3;
  const int width=edge==4?sw:std::min(sw,vertical?static_cast<int>(350*scale*dpi):static_cast<int>(sw*extent));
  const int height=edge==4?sh:std::min(sh,vertical?static_cast<int>(sh*extent):static_cast<int>(270*scale*dpi));
  int x=r.left+static_cast<int>((sw-width)*offset),y=r.top+static_cast<int>((sh-height)*offset);
  if(edge==0)y=r.top;else if(edge==1)y=r.bottom-height;else if(edge==2)x=r.left;else if(edge==3)x=r.right-width;else{x=r.left;y=r.top;}
  POINT point{x,y};MapWindowPoints(HWND_DESKTOP,desktop_host,&point,1);
  SetWindowPos(window,HWND_BOTTOM,point.x,point.y,width,height,SWP_NOACTIVATE|(visible?SWP_SHOWWINDOW:0));}
void Cover(Gdiplus::Graphics& g,RECT r){if(!show_cover||!image)return;const int s=std::min(r.right-r.left,r.bottom-r.top);Gdiplus::GraphicsPath clip;if(style==2)clip.AddEllipse(r.left,r.top,s,s);else clip.AddRectangle(Gdiplus::Rect(r.left,r.top,s,s));const auto saved=g.Save();g.SetClip(&clip);g.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);if(style==2){g.TranslateTransform(r.left+s/2.f,r.top+s/2.f);g.RotateTransform(static_cast<float>(angle));g.TranslateTransform(-r.left-s/2.f,-r.top-s/2.f);}const double ratio=std::max(static_cast<double>(s)/image->GetWidth(),static_cast<double>(s)/image->GetHeight());const int iw=static_cast<int>(image->GetWidth()*ratio),ih=static_cast<int>(image->GetHeight()*ratio);g.DrawImage(image.get(),r.left+(s-iw)/2,r.top+(s-ih)/2,iw,ih);g.Restore(saved);Gdiplus::Pen outline(Accent(),2);if(style==2){g.DrawEllipse(&outline,r.left-5,r.top-5,s+10,s+10);Gdiplus::SolidBrush hole(Gdiplus::Color(255,16,23,30));g.FillEllipse(&hole,r.left+s/2-8,r.top+s/2-8,16,16);}else g.DrawRectangle(&outline,r.left,r.top,s,s);}
void Graph(Gdiplus::Graphics& g,RECT r,const DesktopReadings& data){if(!show_graph||r.right<=r.left||r.bottom<=r.top)return;const float w=static_cast<float>(r.right-r.left),h=static_cast<float>(r.bottom-r.top);const auto accent=Accent();Gdiplus::Pen pen(accent,2.2f);Gdiplus::SolidBrush ink(accent);
  if(graph_style==2){Gdiplus::PointF last(static_cast<float>(r.left),r.top+h/2);for(size_t i=0;i<data.waveform.size();++i){Gdiplus::PointF next(r.left+w*i/(data.waveform.size()-1),r.top+h/2-data.waveform[i]*h*.47f);g.DrawLine(&pen,last,next);last=next;}return;}
  if(graph_style==3){const float radius=std::min(w,h)*.28f,cx=r.left+w/2,cy=r.top+h/2;g.DrawEllipse(&pen,cx-radius,cy-radius,radius*2,radius*2);for(size_t i=0;i<data.bands.size();++i){const double a=i*6.2831853/data.bands.size();const float len=data.bands[i]*std::min(w,h)*.2f;g.DrawLine(&pen,cx+static_cast<float>(std::cos(a))*radius,cy+static_cast<float>(std::sin(a))*radius,cx+static_cast<float>(std::cos(a))*(radius+len),cy+static_cast<float>(std::sin(a))*(radius+len));}return;}
  const float cell=w/data.bands.size();for(size_t i=0;i<data.bands.size();++i){const float level=data.bands[i];const float x=r.left+cell*i,bh=std::max(1.f,level*h*(graph_style==1?.48f:.94f));Gdiplus::LinearGradientBrush gradient(Gdiplus::PointF(x,static_cast<float>(r.bottom)),Gdiplus::PointF(x,static_cast<float>(r.top)),Gdiplus::Color(255,28,55,77),accent);
    if(graph_style==4){for(int j=0;j<static_cast<int>(level*18);++j)g.FillRectangle(&gradient,x,r.bottom-h*(j+1)/18,cell*.7f,std::max(1.f,h/22));}
    else if(graph_style==1){g.FillRectangle(&gradient,x,r.top+h/2-bh,cell*.72f,bh);g.FillRectangle(&gradient,x,r.top+h/2+2,cell*.72f,bh);}
    else g.FillRectangle(&gradient,x,r.bottom-bh,cell*.72f,bh);
  }
}
std::wstring Percent(double n){return n<0?L"--":std::to_wstring(static_cast<int>(std::round(n)))+L"%";}
struct FitRecord {std::wstring text;float width,height,wanted,size;bool bold,centered;};
std::vector<FitRecord> fit_cache;
float FittedFont(Gdiplus::Graphics& g,const std::wstring& text,Gdiplus::RectF r,float wanted,bool bold,bool centered){
  if(!auto_font)return wanted;
  for(const auto& entry:fit_cache)if(entry.text==text&&entry.width==r.Width&&entry.height==r.Height&&entry.wanted==wanted&&entry.bold==bold&&entry.centered==centered)return entry.size;
  Gdiplus::FontFamily family(L"Microsoft YaHei UI");Gdiplus::StringFormat format;format.SetAlignment(centered?Gdiplus::StringAlignmentCenter:Gdiplus::StringAlignmentNear);format.SetTrimming(Gdiplus::StringTrimmingNone);
  float low=std::min(6.f,wanted),high=wanted;
  for(int i=0;i<9;++i){const float size=(low+high)*.5f;Gdiplus::Font font(&family,size,bold?Gdiplus::FontStyleBold:Gdiplus::FontStyleRegular,Gdiplus::UnitPixel);Gdiplus::SizeF measure;INT fitted=0,lines=0;
    g.MeasureString(text.c_str(),static_cast<INT>(text.size()),&font,Gdiplus::SizeF(std::max(1.f,r.Width-4),1000000.f),&format,&measure,&fitted,&lines);
    if(fitted>=static_cast<INT>(text.size())&&measure.Height<=r.Height-2)low=size;else high=size;
  }
  if(fit_cache.size()>=32)fit_cache.erase(fit_cache.begin());fit_cache.push_back(FitRecord{text,r.Width,r.Height,wanted,low,bold,centered});return low;
}
float ComponentFont(RECT r,float ratio,float fallback,float dpi){return auto_font?std::clamp(std::min((r.right-r.left)*ratio,(r.bottom-r.top)*.28f)*static_cast<float>(font_scale),8.f*dpi,160.f*dpi):fallback;}
void AlphaLabel(Gdiplus::Graphics& g,const std::wstring& text,Gdiplus::RectF r,float px,bool bold,Gdiplus::Color ink,bool centered=false){
  if(text.empty()||r.Width<=0||r.Height<=0)return;
  px=FittedFont(g,text,r,px,bold,centered);
  Gdiplus::FontFamily family(L"Microsoft YaHei UI");Gdiplus::Font font(&family,px,bold?Gdiplus::FontStyleBold:Gdiplus::FontStyleRegular,Gdiplus::UnitPixel);
  Gdiplus::StringFormat format;format.SetTrimming(Gdiplus::StringTrimmingEllipsisWord);format.SetAlignment(centered?Gdiplus::StringAlignmentCenter:Gdiplus::StringAlignmentNear);
  Gdiplus::SolidBrush shadow(Gdiplus::Color(165,0,0,0)),brush(ink);
  auto r2=r;r2.X+=1;r2.Y+=2;g.DrawString(text.c_str(),static_cast<INT>(text.size()),&font,r2,&format,&shadow);
  g.DrawString(text.c_str(),static_cast<INT>(text.size()),&font,r,&format,&brush);
}
RECT Bounds(int i,int width,int height){auto b=layout[i];return RECT{static_cast<LONG>(b.x*width),static_cast<LONG>(b.y*height),static_cast<LONG>(std::min(1.,b.x+b.w)*width),static_cast<LONG>(std::min(1.,b.y+b.h)*height)};}
Gdiplus::RectF FloatRect(RECT r){return Gdiplus::RectF(static_cast<float>(r.left),static_cast<float>(r.top),static_cast<float>(r.right-r.left),static_cast<float>(r.bottom-r.top));}
void Render(){
  if(!visible||!IsWindow(window)||!IsWindow(desktop_host))return;
  RECT area{};GetClientRect(window,&area);const int width=area.right,height=area.bottom;if(width<=0||height<=0||width>16384||height>16384)return;
  HDC screen=GetDC(nullptr);
  if(!buffer_dc||buffer_w!=width||buffer_h!=height){ReleaseBuffer();buffer_dc=CreateCompatibleDC(screen);BITMAPINFO info{};info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);info.bmiHeader.biWidth=width;info.bmiHeader.biHeight=-height;info.bmiHeader.biPlanes=1;info.bmiHeader.biBitCount=32;info.bmiHeader.biCompression=BI_RGB;buffer_bitmap=CreateDIBSection(screen,&info,DIB_RGB_COLORS,&buffer_bits,nullptr,0);if(!buffer_bitmap){DeleteDC(buffer_dc);buffer_dc=nullptr;ReleaseDC(nullptr,screen);return;}buffer_old=static_cast<HBITMAP>(SelectObject(buffer_dc,buffer_bitmap));buffer_w=width;buffer_h=height;}
  auto data=telemetry.Read();if(!playing){data.bands.fill(0);data.waveform.fill(0);}
  {Gdiplus::Bitmap surface(width,height,width*4,PixelFormat32bppPARGB,static_cast<BYTE*>(buffer_bits));Gdiplus::Graphics g(&surface);g.SetCompositingMode(Gdiplus::CompositingModeSourceCopy);g.Clear(Gdiplus::Color(0,0,0,0));g.SetCompositingMode(Gdiplus::CompositingModeSourceOver);g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);g.SetTextRenderingHint(Gdiplus::TextRenderingHintAntiAliasGridFit);
    const float px=static_cast<float>(std::clamp(22.*scale*font_scale*GetDpiForWindow(window)/96.,12.,96.));
    const float dpi=GetDpiForWindow(window)/96.f;
    auto cover=Bounds(0,width,height);const float cover_font=auto_font?std::clamp(std::min((cover.right-cover.left)*.095f,(cover.bottom-cover.top)*.065f)*static_cast<float>(font_scale),8.f*dpi,100.f*dpi):px;const auto cover_state=g.Save();g.SetClip(FloatRect(cover));
    RECT art=cover;const int reserve=static_cast<int>((show_title?cover_font*2.3f:0)+(show_artist?cover_font*1.7f:0)+12);art.bottom=std::max(art.top,art.bottom-reserve);
    const int art_size=show_cover?std::max<LONG>(0,std::min(art.right-art.left,art.bottom-art.top)):0;if(art_size>0)Cover(g,art);
    if(show_title||show_artist){auto r=FloatRect(cover);r.Y+=art_size+12;r.Height=cover_font*2.3f;if(show_title){AlphaLabel(g,title,r,cover_font,true,Gdiplus::Color(255,245,249,255));r.Y+=r.Height;}r.Height=cover_font*1.7f;if(show_artist)AlphaLabel(g,artist,r,cover_font*.65f,false,Gdiplus::Color(255,183,209,220));}
    g.Restore(cover_state);
    if(show_lyrics){const auto box=Bounds(1,width,height);const float lyrics_font=ComponentFont(box,.08f,px*1.7f,dpi);auto r=FloatRect(box);auto tr=r;tr.Y+=r.Height*.62f;tr.Height=r.Height*.38f;r.Height*=.62f;AlphaLabel(g,lyric,r,lyrics_font,true,Gdiplus::Color(255,247,250,255),true);if(show_translation)AlphaLabel(g,translation,tr,lyrics_font*.48f,false,Accent(),true);}
    if(show_graph)Graph(g,Bounds(2,width,height),data);
    if(show_stats){std::vector<std::wstring> items;const std::wstring values[]={L"CPU "+Percent(data.cpu),L"GPU "+Percent(data.gpu),L"RAM "+Percent(data.ram_percent),data.memory_clock?L"RAM CONFIG "+std::to_wstring(data.memory_clock)+L" MHz":L"RAM CONFIG --",data.cpu_clock?L"CPU "+std::to_wstring(data.cpu_clock)+L" MHz":L"CPU MHz --",data.gpu_clock?L"GPU "+std::to_wstring(data.gpu_clock)+L" MHz":L"GPU MHz --",data.gpu_memory_clock?L"VRAM "+std::to_wstring(data.gpu_memory_clock)+L" MHz":L"VRAM MHz --"};for(int i=0;i<7;++i)if(stat_items[i])items.push_back(values[i]);auto r=FloatRect(Bounds(3,width,height));const float stat_px=auto_font?std::clamp(std::min(r.Height*.36f,r.Width/std::max<size_t>(1,items.size())*.12f)*static_cast<float>(font_scale),7.f*dpi,70.f*dpi):px*.72f;const auto stats_state=g.Save();g.SetClip(r);const int cols=std::max(1,std::min(static_cast<int>(items.size()),static_cast<int>(r.Width/(stat_px*8))));for(size_t i=0;i<items.size();++i){Gdiplus::RectF cell(r.X+static_cast<int>(i%cols)*r.Width/cols,r.Y+static_cast<int>(i/cols)*stat_px*1.8f,r.Width/cols,stat_px*1.8f);AlphaLabel(g,items[i],cell,stat_px,true,Accent());}g.Restore(stats_state);}
    if(show_progress){const auto r=FloatRect(Bounds(4,width,height));const float thickness=std::min(static_cast<float>(progress_thickness)*dpi,r.Height*.7f),radius=std::min(static_cast<float>(progress_thumb)*dpi,r.Height*.48f),pad=std::max(radius,thickness*.5f);const float left=r.X+pad,right=std::max(left,r.GetRight()-pad),y=r.Y+r.Height*.5f,at=left+(right-left)*static_cast<float>(progress);Gdiplus::Pen base(Gdiplus::Color(80,155,185,195),thickness),active(Accent(),thickness);base.SetStartCap(Gdiplus::LineCapRound);base.SetEndCap(Gdiplus::LineCapRound);active.SetStartCap(Gdiplus::LineCapRound);active.SetEndCap(Gdiplus::LineCapRound);g.DrawLine(&base,left,y,right,y);g.DrawLine(&active,left,y,at,y);if(radius>0){Gdiplus::SolidBrush dot(Accent());g.FillEllipse(&dot,at-radius,y-radius,radius*2,radius*2);}}

  }
  POINT dst{};ClientToScreen(window,&dst);POINT src{};SIZE size{width,height};BLENDFUNCTION blend{AC_SRC_OVER,0,255,AC_SRC_ALPHA};UpdateLayeredWindow(window,screen,&dst,&size,buffer_dc,&src,0,&blend,ULW_ALPHA);ReleaseDC(nullptr,screen);
}
void Tray(bool add){if(!window)return;NOTIFYICONDATAW n{};n.cbSize=sizeof(n);n.hWnd=window;n.uID=1;n.uFlags=NIF_ICON|NIF_MESSAGE|NIF_TIP;n.uCallbackMessage=tray_message;n.hIcon=LoadIcon(GetModuleHandle(nullptr),MAKEINTRESOURCE(IDI_APP_ICON));wcscpy_s(n.szTip,L"Vocalo1ng 桌面模式 · 双击开关 · Ctrl+Alt+D");Shell_NotifyIconW(add?NIM_ADD:NIM_DELETE,&n);tray=add;}
void RefreshDesktopTimer(){
  if(!window||!visible)return;
  telemetry.SetConsumer("desktop",playing&&show_graph,show_stats);
  const bool animated=playing&&(show_graph||(show_cover&&style==2));
  SetTimer(window,1,animated?33:1000,nullptr);
}
void SetVisible(bool on,bool notify){visible=on;if(window){if(on){RefreshDesktopTimer();Position();ShowWindow(window,SW_SHOWNOACTIVATE);Render();}else{KillTimer(window,1);ShowWindow(window,SW_HIDE);telemetry.SetConsumer("desktop",false,false);ReleaseBuffer();}}if(notify&&channel)channel->InvokeMethod("visibility",std::make_unique<Value>(on));}
void Destroy(){SetVisible(false,false);if(window){if(tray)Tray(false);UnregisterHotKey(window,hotkey_id);DestroyWindow(window);window=nullptr;}ReleaseCover();ReleaseBuffer();fit_cache.clear();}
LRESULT CALLBACK Procedure(HWND hwnd,UINT message,WPARAM w,LPARAM l){switch(message){
  case WM_DESTROY:visible=false;KillTimer(hwnd,1);telemetry.SetConsumer("desktop",false,false);ReleaseBuffer();if(channel)channel->InvokeMethod("visibility",std::make_unique<Value>(false));return 0;
  case WM_NCHITTEST:return HTTRANSPARENT;case WM_MOUSEACTIVATE:return MA_NOACTIVATE;case WM_ERASEBKGND:return 1;
  case WM_DISPLAYCHANGE:case WM_DPICHANGED:Position();return 0;
  case WM_HOTKEY:if(w==hotkey_id){SetVisible(!visible,true);return 0;}break;
  case tray_message:if(l==WM_LBUTTONDBLCLK){SetVisible(!visible,true);return 0;}if(l==WM_RBUTTONUP||l==WM_CONTEXTMENU){HMENU menu=CreatePopupMenu();AppendMenuW(menu,MF_STRING,1,visible?L"隐藏桌面模式  Ctrl+Alt+D":L"显示桌面模式  Ctrl+Alt+D");AppendMenuW(menu,MF_STRING,2,L"退出桌面模式");POINT p;GetCursorPos(&p);const int selected=TrackPopupMenu(menu,TPM_RETURNCMD|TPM_NONOTIFY|TPM_RIGHTBUTTON,p.x,p.y,0,hwnd,nullptr);DestroyMenu(menu);if(selected==1)SetVisible(!visible,true);else if(selected==2){SetVisible(false,true);if(tray)Tray(false);UnregisterHotKey(window,hotkey_id);}return 0;}break;
  case WM_TIMER:if(!IsWindow(desktop_host)){SetVisible(false,true);return 0;}if(playing&&(show_graph||(show_cover&&style==2))) {angle=std::fmod(angle+.462,360.);Render();}else if(show_stats)Render();return 0;
  case WM_PAINT:{PAINTSTRUCT ps;BeginPaint(hwnd,&ps);EndPaint(hwnd,&ps);Render();return 0;}
  }return DefWindowProc(hwnd,message,w,l);}
}
void RegisterDesktopWindow(flutter::BinaryMessenger* messenger){channel=std::make_unique<flutter::MethodChannel<Value>>(messenger,"vocalo1ng/desktop",&flutter::StandardMethodCodec::GetInstance());channel->SetMethodCallHandler([](const flutter::MethodCall<Value>& call,std::unique_ptr<flutter::MethodResult<Value>> result){const auto* args=call.arguments();const auto* data=args?std::get_if<Map>(args):nullptr;
  if(call.method_name()=="close"){Destroy();result->Success();return;}if(call.method_name()=="hide"){SetVisible(false,false);result->Success();return;}
  if(call.method_name()=="show"&&data){edge=std::clamp(static_cast<int>(Number(*data,"edge",4)),0,4);style=std::clamp(static_cast<int>(Number(*data,"style",0)),0,5);graph_style=std::clamp(static_cast<int>(Number(*data,"graphStyle",0)),0,4);scale=std::clamp(Number(*data,"scale",1),.65,1.5);opacity=std::clamp(Number(*data,"opacity",.94),.3,1.);extent=std::clamp(Number(*data,"extent",1),.3,1.);offset=std::clamp(Number(*data,"offset",.5),0.,1.);graph_extent=std::clamp(Number(*data,"graphExtent",.35),.15,.55);show_cover=Flag(*data,"showCover",true);show_lyrics=Flag(*data,"showLyrics",true);show_graph=Flag(*data,"showGraph",true);show_stats=Flag(*data,"showStats",true);show_progress=Flag(*data,"showProgress",true);
    transparent_background=Flag(*data,"transparentBackground",true);show_title=Flag(*data,"showTitle",true);show_artist=Flag(*data,"showArtist",true);show_translation=Flag(*data,"showTranslation",true);font_scale=std::clamp(Number(*data,"fontScale",1),.65,2.);auto_font=Flag(*data,"autoFont",true);progress_thickness=std::clamp(Number(*data,"progressThickness",4),1.,24.);progress_thumb=std::clamp(Number(*data,"progressThumb",5),0.,20.);
    if(const auto* raw=Field(*data,"layout")){if(const auto* boxes=std::get_if<Map>(raw)){const char* keys[]={"cover","lyrics","graph","stats","progress"};for(int i=0;i<5;++i){const auto* value=Field(*boxes,keys[i]);const auto* list=value?std::get_if<flutter::EncodableList>(value):nullptr;if(list&&list->size()==4){double n[4];bool valid=true;for(int j=0;j<4;++j){const auto* d=std::get_if<double>(&(*list)[j]);if(!d||!std::isfinite(*d)){valid=false;break;}n[j]=std::clamp(*d,0.,1.);}if(valid)layout[i]=Box{std::min(.95,n[0]),std::min(.95,n[1]),std::max(.04,n[2]),std::max(.04,n[3])};}}}}
    const auto* choices=Field(*data,"statItems");const auto* list=choices?std::get_if<flutter::EncodableList>(choices):nullptr;
    const char* names[]={"cpu","gpu","ram","clock","cpuClock","gpuClock","gpuMemoryClock"};for(int i=0;i<7;++i){stat_items[i]=!list;if(list)for(const auto& item:*list){const auto* key=std::get_if<std::string>(&item);if(key&&*key==names[i])stat_items[i]=true;}}

    if(!graphics_token){Gdiplus::GdiplusStartupInput input;Gdiplus::GdiplusStartup(&graphics_token,&input,nullptr);}
    if(window&&!IsWindow(window)){window=nullptr;desktop_host=nullptr;tray=false;}
    if(!window){WNDCLASSW wc{};wc.lpfnWndProc=Procedure;wc.hInstance=GetModuleHandle(nullptr);wc.lpszClassName=L"Vocalo1ngDesktopOverlay";RegisterClassW(&wc);window=CreateWindowExW(WS_EX_TOOLWINDOW|WS_EX_LAYERED|WS_EX_TRANSPARENT|WS_EX_NOACTIVATE,wc.lpszClassName,L"Vocalo1ng Desktop",WS_POPUP,40,40,600,270,nullptr,nullptr,wc.hInstance,nullptr);}
    if(window&&!AttachDesktop()){result->Error("desktop_host","无法连接桌面图标后方的壁纸层，请重启资源管理器后重试");return;}
    if(window){if(!tray)Tray(true);RegisterHotKey(window,hotkey_id,MOD_CONTROL|MOD_ALT|MOD_NOREPEAT,'D');SetVisible(true,false);}result->Success(Value(window!=nullptr));return;
  }
  if(call.method_name()=="cover"){ReleaseCover();const auto* bytes=args?std::get_if<std::vector<uint8_t>>(args):nullptr;if(bytes&&!bytes->empty()&&bytes->size()<4*1024*1024&&SUCCEEDED(CreateStreamOnHGlobal(nullptr,TRUE,&image_stream))){ULONG written=0;image_stream->Write(bytes->data(),static_cast<ULONG>(bytes->size()),&written);LARGE_INTEGER zero{};image_stream->Seek(zero,STREAM_SEEK_SET,nullptr);image=std::make_unique<Gdiplus::Bitmap>(image_stream);if(image->GetLastStatus()!=Gdiplus::Ok||image->GetWidth()==0||image->GetHeight()==0||image->GetWidth()>4096||image->GetHeight()>4096)ReleaseCover();else{const double factor=std::min(1.,768./std::max(image->GetWidth(),image->GetHeight()));const int iw=std::max(1,static_cast<int>(image->GetWidth()*factor)),ih=std::max(1,static_cast<int>(image->GetHeight()*factor));auto bounded=std::make_unique<Gdiplus::Bitmap>(iw,ih,PixelFormat32bppPARGB);{Gdiplus::Graphics g(bounded.get());g.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);g.DrawImage(image.get(),0,0,iw,ih);}ReleaseCover();image=std::move(bounded);}}result->Success();return;}
  if(call.method_name()=="update"&&data){const auto previous=std::make_tuple(title,artist,lyric,translation,progress,playing);title=Text(*data,"title");artist=Text(*data,"artist");lyric=Text(*data,"line");translation=Text(*data,"translation");progress=std::clamp(Number(*data,"progress",0),0.,1.);const bool was_playing=playing;playing=Flag(*data,"playing",false);if(was_playing!=playing)RefreshDesktopTimer();if(visible&&previous!=std::make_tuple(title,artist,lyric,translation,progress,playing))Render();result->Success();return;}
  result->NotImplemented();});}
void CloseDesktopWindow(){Destroy();channel.reset();if(graphics_token){Gdiplus::GdiplusShutdown(graphics_token);graphics_token=0;}}
