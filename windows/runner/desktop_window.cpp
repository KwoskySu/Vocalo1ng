#include "desktop_window.h"
#include <windows.h>
#include <objidl.h>
#include <gdiplus.h>
#include <mmdeviceapi.h>
#include <endpointvolume.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <algorithm>
#include <array>
#include <cmath>
#include <memory>
#include <string>
#include <vector>

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
std::unique_ptr<flutter::MethodChannel<Value>> channel;
HWND window = nullptr;
ULONG_PTR graphics_token = 0;
IAudioMeterInformation* meter = nullptr;
IStream* image_stream = nullptr;
std::unique_ptr<Gdiplus::Bitmap> image;
std::array<float, 48> levels{};
std::wstring title = L"等待播放", artist, lyric, translation;
int edge = 1;
double scale = 1, opacity = .94, extent = .65, offset = .5, progress = 0;
bool show_cover = true, show_lyrics = true, show_graph = true, show_progress = true, playing = false;
const COLORREF transparent = RGB(1, 0, 1);
const Value* Field(const Map& map, const char* key) { const auto it=map.find(Value(key));return it==map.end()?nullptr:&it->second; }
double Number(const Map& map,const char* key,double fallback) {
  const auto* v=Field(map,key);if(!v)return fallback;
  if(const auto* n=std::get_if<double>(v))return std::isfinite(*n)?*n:fallback;
  if(const auto* n=std::get_if<int32_t>(v))return *n;
  if(const auto* n=std::get_if<int64_t>(v))return static_cast<double>(*n);
  return fallback;
}
bool Flag(const Map& map,const char* key,bool fallback) {const auto* v=Field(map,key);const auto* b=v?std::get_if<bool>(v):nullptr;return b?*b:fallback;}
std::wstring Text(const Map& map,const char* key) {
  const auto* v=Field(map,key);const auto* s=v?std::get_if<std::string>(v):nullptr;if(!s||s->empty())return L"";
  const int n=MultiByteToWideChar(CP_UTF8,0,s->data(),static_cast<int>(s->size()),nullptr,0);
  std::wstring out(n,0);MultiByteToWideChar(CP_UTF8,0,s->data(),static_cast<int>(s->size()),out.data(),n);return out;
}
void ReleaseCover() { image.reset();if(image_stream){image_stream->Release();image_stream=nullptr;} }
void AudioMeter() {
  if(meter)return;
  IMMDeviceEnumerator* enumerator=nullptr;IMMDevice* device=nullptr;
  if(SUCCEEDED(CoCreateInstance(__uuidof(MMDeviceEnumerator),nullptr,CLSCTX_ALL,__uuidof(IMMDeviceEnumerator),reinterpret_cast<void**>(&enumerator)))) {
    if(SUCCEEDED(enumerator->GetDefaultAudioEndpoint(eRender,eMultimedia,&device))) {
      device->Activate(__uuidof(IAudioMeterInformation),CLSCTX_ALL,nullptr,reinterpret_cast<void**>(&meter));device->Release();
    }
    enumerator->Release();
  }
}
void Position() {
  if(!window)return;
  MONITORINFO monitor{sizeof(MONITORINFO)};
  GetMonitorInfo(MonitorFromWindow(window,MONITOR_DEFAULTTONEAREST),&monitor);
  const RECT r=monitor.rcWork;const int sw=r.right-r.left,sh=r.bottom-r.top;
  const double dpi=GetDpiForWindow(window)/96.0;
  const bool vertical=edge>=2;
  const int width=std::min(sw,vertical?static_cast<int>(285*scale*dpi):static_cast<int>(sw*extent));
  const int height=std::min(sh,vertical?static_cast<int>(sh*extent):static_cast<int>(140*scale*dpi));
  int x=r.left+static_cast<int>((sw-width)*offset),y=r.top+static_cast<int>((sh-height)*offset);
  if(edge==0)y=r.top+6;else if(edge==1)y=r.bottom-height-6;
  else if(edge==2)x=r.left+6;else x=r.right-width-6;
  SetWindowPos(window,HWND_TOPMOST,x,y,width,height,SWP_NOACTIVATE|SWP_SHOWWINDOW);
}
void Label(HDC dc,const std::wstring& text,RECT r,int px,bool bold=false,COLORREF color=RGB(244,248,250)) {
  const auto font=CreateFontW(-px,0,0,0,bold?FW_BOLD:FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,ANTIALIASED_QUALITY,DEFAULT_PITCH,L"Microsoft YaHei UI");
  const auto old=SelectObject(dc,font);SetTextColor(dc,color);SetBkMode(dc,TRANSPARENT);
  // A subtle dark shadow remains readable on light desktops.
  RECT shadow=r;OffsetRect(&shadow,1,1);SetTextColor(dc,RGB(22,28,34));
  DrawTextW(dc,text.c_str(),static_cast<int>(text.size()),&shadow,DT_LEFT|DT_TOP|DT_WORDBREAK|DT_END_ELLIPSIS|DT_NOPREFIX);
  SetTextColor(dc,color);DrawTextW(dc,text.c_str(),static_cast<int>(text.size()),&r,DT_LEFT|DT_TOP|DT_WORDBREAK|DT_END_ELLIPSIS|DT_NOPREFIX);
  SelectObject(dc,old);DeleteObject(font);
}
LRESULT CALLBACK Procedure(HWND hwnd,UINT message,WPARAM w,LPARAM l) {
  switch(message) {
    case WM_NCHITTEST:return HTTRANSPARENT;
    case WM_MOUSEACTIVATE:return MA_NOACTIVATE;
    case WM_DISPLAYCHANGE:case WM_DPICHANGED:Position();return 0;
    case WM_ERASEBKGND:return 1;
    case WM_TIMER: {
      if(show_graph){AudioMeter();float peak=0;if(meter&&FAILED(meter->GetPeakValue(&peak))){meter->Release();meter=nullptr;}
        std::move(levels.begin()+1,levels.end(),levels.begin());levels.back()=std::clamp(peak,0.f,1.f);}
      InvalidateRect(hwnd,nullptr,FALSE);return 0;
    }
    case WM_PAINT: {
      PAINTSTRUCT ps;HDC target=BeginPaint(hwnd,&ps);RECT r;GetClientRect(hwnd,&r);const int width=static_cast<int>(r.right),height=static_cast<int>(r.bottom);
      HDC dc=CreateCompatibleDC(target);HBITMAP bitmap=CreateCompatibleBitmap(target,width,height);const auto old=SelectObject(dc,bitmap);
      HBRUSH key=CreateSolidBrush(transparent);FillRect(dc,&r,key);DeleteObject(key);
      const double dpi=GetDpiForWindow(hwnd)/96.0;const int unit=std::max(1,static_cast<int>(12*scale*dpi));
      const bool vertical=edge>=2;int x=unit,y=unit;const int right=width-unit;
      const int cover_size=vertical?std::min(width-unit*2,height/3):std::min(height-unit*3,static_cast<int>(92*scale*dpi));
      if(show_cover&&image) {
        Gdiplus::Graphics g(dc);g.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBicubic);
        const double ratio=std::min(static_cast<double>(cover_size)/image->GetWidth(),static_cast<double>(cover_size)/image->GetHeight());
        const int iw=static_cast<int>(image->GetWidth()*ratio),ih=static_cast<int>(image->GetHeight()*ratio);
        g.DrawImage(image.get(),x+(cover_size-iw)/2,y+(cover_size-ih)/2,iw,ih);
        if(vertical)y+=cover_size+unit;else x+=cover_size+unit;
      }
      const int font=std::max(12,static_cast<int>(17*scale*dpi));
      const int text_right=show_graph&&!vertical?right-std::min((right-x)/3,180)-unit:right;
      RECT tr{x,y,text_right,y+font*2};Label(dc,title,tr,font,true);y+=font*2;
      RECT ar{x,y,text_right,y+font*2};Label(dc,artist,ar,font*3/4,false,RGB(182,211,222));y+=font+unit/2;
      if(show_lyrics) {
        const int lyric_height=vertical?std::min(font*5,std::max(font*2,height-y-font*5)):font*2;
        RECT lr{x,y,text_right,std::min(height-unit*2,y+lyric_height)};Label(dc,lyric,lr,font,true);y+=lyric_height;
        if(vertical){RECT translated{x,y,right,std::min(height-unit*2,y+font*3)};Label(dc,translation,translated,font*3/4,false,RGB(171,226,223));}
      }
      if(show_graph) {
        const int graph_height=vertical?font*3:font*2;
        const int graph_width=vertical?right-x:std::min((right-x)/3,180);
        const int gx=vertical?x:right-graph_width,gy=height-unit*2-graph_height;
        HBRUSH bar=CreateSolidBrush(playing?RGB(129,219,208):RGB(142,158,164));
        for(size_t i=0;i<levels.size();++i){const int px=gx+static_cast<int>(i)*graph_width/static_cast<int>(levels.size());const int h=static_cast<int>(std::sqrt(levels[i])*graph_height);RECT br{px,gy+graph_height-h,px+std::max(1,graph_width/static_cast<int>(levels.size())-1),gy+graph_height};FillRect(dc,&br,bar);}DeleteObject(bar);
      }
      if(show_progress){RECT bg{unit,height-unit,right,height-unit+3};HBRUSH b=CreateSolidBrush(RGB(56,68,76));FillRect(dc,&bg,b);DeleteObject(b);bg.right=unit+static_cast<int>((right-unit)*progress);b=CreateSolidBrush(RGB(139,232,218));FillRect(dc,&bg,b);DeleteObject(b);}
      BitBlt(target,0,0,width,height,dc,0,0,SRCCOPY);SelectObject(dc,old);DeleteObject(bitmap);DeleteDC(dc);EndPaint(hwnd,&ps);return 0;
    }
  }
  return DefWindowProc(hwnd,message,w,l);
}
void Hide() {
  if(window){KillTimer(window,1);DestroyWindow(window);window=nullptr;}
  if(meter){meter->Release();meter=nullptr;}ReleaseCover();levels.fill(0);
}
}
void RegisterDesktopWindow(flutter::BinaryMessenger* messenger) {
  channel=std::make_unique<flutter::MethodChannel<Value>>(messenger,"vocalo1ng/desktop",&flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([](const flutter::MethodCall<Value>& call,std::unique_ptr<flutter::MethodResult<Value>> result){
    const auto* args=call.arguments();const auto* data=args?std::get_if<Map>(args):nullptr;
    if(call.method_name()=="close"){Hide();result->Success();return;}
    if(call.method_name()=="show"&&data){
      edge=std::clamp(static_cast<int>(Number(*data,"edge",1)),0,3);scale=std::clamp(Number(*data,"scale",1),.65,1.5);opacity=std::clamp(Number(*data,"opacity",.94),.3,1.0);extent=std::clamp(Number(*data,"extent",.65),.3,.95);offset=std::clamp(Number(*data,"offset",.5),0.,1.);
      show_cover=Flag(*data,"showCover",true);show_lyrics=Flag(*data,"showLyrics",true);show_graph=Flag(*data,"showGraph",true);show_progress=Flag(*data,"showProgress",true);
      if(!graphics_token){Gdiplus::GdiplusStartupInput input;Gdiplus::GdiplusStartup(&graphics_token,&input,nullptr);}
      if(!window){WNDCLASSW wc{};wc.lpfnWndProc=Procedure;wc.hInstance=GetModuleHandle(nullptr);wc.lpszClassName=L"Vocalo1ngDesktopOverlay";RegisterClassW(&wc);
        // Both styles and hit testing enforce click-through without activation.
        window=CreateWindowExW(WS_EX_TOPMOST|WS_EX_TOOLWINDOW|WS_EX_LAYERED|WS_EX_TRANSPARENT|WS_EX_NOACTIVATE,wc.lpszClassName,L"Vocalo1ng Desktop",WS_POPUP,40,40,600,140,nullptr,nullptr,wc.hInstance,nullptr);
        if(window)SetTimer(window,1,80,nullptr);
      }
      if(window){SetLayeredWindowAttributes(window,transparent,static_cast<BYTE>(opacity*255),LWA_COLORKEY|LWA_ALPHA);Position();InvalidateRect(window,nullptr,FALSE);}
      result->Success(Value(window!=nullptr));return;
    }
    if(call.method_name()=="cover"){
      ReleaseCover();const auto* bytes=args?std::get_if<std::vector<uint8_t>>(args):nullptr;
      if(bytes&&!bytes->empty()&&bytes->size()<4*1024*1024&&SUCCEEDED(CreateStreamOnHGlobal(nullptr,TRUE,&image_stream))){
        ULONG written=0;image_stream->Write(bytes->data(),static_cast<ULONG>(bytes->size()),&written);LARGE_INTEGER zero{};image_stream->Seek(zero,STREAM_SEEK_SET,nullptr);
        image=std::make_unique<Gdiplus::Bitmap>(image_stream);if(image->GetLastStatus()!=Gdiplus::Ok)ReleaseCover();
      }
      result->Success();return;
    }
    if(call.method_name()=="update"&&data){title=Text(*data,"title");artist=Text(*data,"artist");lyric=Text(*data,"line");translation=Text(*data,"translation");progress=std::clamp(Number(*data,"progress",0),0.,1.);playing=Flag(*data,"playing",false);result->Success();return;}
    result->NotImplemented();
  });
}
void CloseDesktopWindow(){Hide();channel.reset();if(graphics_token){Gdiplus::GdiplusShutdown(graphics_token);graphics_token=0;}}
