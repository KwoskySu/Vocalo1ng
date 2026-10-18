#include "floating_window.h"
#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <algorithm>
#include <memory>
#include <string>

namespace {
using Value = flutter::EncodableValue;
using Map = flutter::EncodableMap;
std::unique_ptr<flutter::MethodChannel<Value>> channel;
HWND floating = nullptr;
std::wstring original = L"VOCALO1ng", translation, following, title;
int mode = 0, font_size = 24;
int text_effect = 0, font_face = 0;
COLORREF text_color = RGB(255,255,255);
double progress = 0, opacity = .92;
bool playing = false;
std::wstring Wide(const std::string& text) {
  int count = MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, nullptr, 0);
  std::wstring result(static_cast<size_t>(count), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.c_str(), -1, result.data(), count);
  if (!result.empty()) result.pop_back();
  return result;
}
const Value* Field(const Map& data, const char* key) {
  const auto found = data.find(Value(key));
  return found == data.end() ? nullptr : &found->second;
}
std::wstring Text(const Map& data, const char* key) {
  const auto v = Field(data, key);
  return v && std::holds_alternative<std::string>(*v) ? Wide(std::get<std::string>(*v)) : L"";
}
double Number(const Map& data, const char* key, double fallback) {
  const auto v = Field(data, key);
  if (!v) return fallback;
  if (std::holds_alternative<double>(*v)) return std::get<double>(*v);
  if (std::holds_alternative<int32_t>(*v)) return std::get<int32_t>(*v);
  if (std::holds_alternative<int64_t>(*v)) return static_cast<double>(std::get<int64_t>(*v));
  return fallback;
}
void Label(HDC dc, const std::wstring& text, RECT rect, int size, COLORREF color, bool bold = false) {
  HFONT font = CreateFontW(-MulDiv(size, GetDpiForWindow(floating), 96), 0, 0, 0,
      bold && text_effect != 1 ? FW_BOLD : FW_NORMAL, text_effect == 4, FALSE, FALSE, DEFAULT_CHARSET,
      OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY, DEFAULT_PITCH,
      font_face == 1 ? L"SimSun" : font_face == 2 ? L"KaiTi" : font_face == 3 ? L"Consolas" : L"Microsoft YaHei UI");
  auto old = SelectObject(dc, font);
  SetTextColor(dc, color);
  const int spacing = SetTextCharacterExtra(dc, text_effect == 5 ? 3 : 0);
  if(text_effect == 2 || text_effect == 3) {
    SetTextColor(dc,text_effect==2?RGB(0,0,0):RGB(GetRValue(color)/2,GetGValue(color)/2,GetBValue(color)/2));
    for(int x=-1;x<=1;x++) for(int y=-1;y<=1;y++) {
      if(x==0 && y==0)continue;
      RECT shadow=rect;OffsetRect(&shadow,x*(text_effect==3?2:1),y*(text_effect==3?2:1));
      DrawTextW(dc,text.c_str(),-1,&shadow,DT_CENTER|DT_VCENTER|DT_WORDBREAK|DT_NOPREFIX);
    }
    SetTextColor(dc,color);
  }
  DrawTextW(dc, text.c_str(), -1, &rect, DT_CENTER | DT_VCENTER | DT_WORDBREAK | DT_NOPREFIX);
  SetTextCharacterExtra(dc,spacing); SelectObject(dc, old); DeleteObject(font);
}
LRESULT CALLBACK Procedure(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  switch (message) {
    case WM_ERASEBKGND: return 1;
    case WM_NCHITTEST: {
      POINT point{static_cast<short>(LOWORD(lparam)), static_cast<short>(HIWORD(lparam))};
      ScreenToClient(hwnd, &point);
      RECT r; GetClientRect(hwnd, &r);
      if (point.x > r.right - 12 && point.y > r.bottom - 12) return HTBOTTOMRIGHT;
      return HTCLIENT;
    }
    case WM_LBUTTONDOWN: {
      RECT r; GetClientRect(hwnd, &r);
      const int x = LOWORD(lparam), y = HIWORD(lparam);
      if (x > r.right - 40 && y < 38) { SendMessage(hwnd, WM_CLOSE, 0, 0); return 0; }
      if ((mode == 2 || mode == 3) && y > r.bottom - 45 && channel) {
        const char* command = x < r.right / 3 ? "previous" : x > r.right * 2 / 3 ? "next" : "toggle";
        channel->InvokeMethod(command, nullptr); return 0;
      }
      ReleaseCapture(); SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0); return 0;
    }
    case WM_RBUTTONUP:
      SendMessage(hwnd, WM_CLOSE, 0, 0); return 0;
    case WM_CLOSE:
      ShowWindow(hwnd, SW_HIDE);
      if (channel) channel->InvokeMethod("closed", nullptr);
      return 0;
    case WM_SIZE: InvalidateRect(hwnd, nullptr, FALSE); return 0;
    case WM_PAINT: {
      PAINTSTRUCT ps; HDC target = BeginPaint(hwnd, &ps);
      RECT r; GetClientRect(hwnd, &r);
      HDC dc = CreateCompatibleDC(target);
      HBITMAP bitmap = CreateCompatibleBitmap(target, r.right, r.bottom);
      auto old_bitmap = SelectObject(dc, bitmap);
      HBRUSH brush = CreateSolidBrush(opacity == 0 ? RGB(1,0,1) : mode == 4 ? RGB(32,10,48) : mode == 2 ? RGB(30,48,63) : RGB(12,16,24));
      FillRect(dc, &r, brush); DeleteObject(brush); SetBkMode(dc, TRANSPARENT);
      RECT close{r.right - 36, 3, r.right - 5, 32};
      Label(dc, L"×", close, 22, RGB(230,235,240));
      const int bottom = (mode == 2 || mode == 3) ? r.bottom - 45 : r.bottom - 6;
      RECT line{18, mode == 6 ? 42 : 12, r.right - 18, bottom - (translation.empty() ? 4 : 35) - ((mode == 1 || mode == 7) ? 30 : 0)};
      if (mode == 6) {
        RECT heading{18, 8, r.right - 40, 40};
        Label(dc, title, heading, std::max(12, font_size / 2), RGB(150,160,175));
      }
      if (mode == 4) {
        RECT shadow = line; OffsetRect(&shadow, 2, 2);
        Label(dc, original, shadow, font_size, RGB(170,40,180), true);
      }
      Label(dc, original, line, font_size, mode == 0 ? RGB(245,247,252) : text_color, true);
      if (mode == 0) {
        int saved = SaveDC(dc);
        IntersectClipRect(dc, line.left, line.top, line.left + static_cast<int>((line.right - line.left) * progress), line.bottom);
        Label(dc, original, line, font_size, text_color, true); RestoreDC(dc, saved);
      }
      if (!translation.empty()) {
        RECT translated{18, line.bottom, r.right - 18, line.bottom + 35};
        Label(dc, translation, translated, std::max(12, font_size * 2 / 3), RGB(148,232,237));
      }
      if (mode == 1 || mode == 7) {
        RECT next{18, bottom - 30, r.right - 18, bottom};
        Label(dc, following, next, std::max(12, font_size * 2 / 3), RGB(150,160,175));
      }
      if (mode == 7) {
        RECT meter{18, r.bottom - 5, 18 + static_cast<int>((r.right - 36) * progress), r.bottom - 3};
        HBRUSH accent = CreateSolidBrush(text_color); FillRect(dc, &meter, accent); DeleteObject(accent);
      }
      if (mode == 2 || mode == 3) {
        RECT previous{10, bottom, r.right / 3, r.bottom},
            toggle{r.right / 3, bottom, r.right * 2 / 3, r.bottom},
            next{r.right * 2 / 3, bottom, r.right - 10, r.bottom};
        Label(dc, L"上一首", previous, 13, RGB(220,230,240));
        Label(dc, playing ? L"暂停" : L"播放", toggle, 15, RGB(148,232,237), true);
        Label(dc, L"下一首", next, 13, RGB(220,230,240));
      }
      BitBlt(target, 0, 0, r.right, r.bottom, dc, 0, 0, SRCCOPY);
      SelectObject(dc, old_bitmap); DeleteObject(bitmap); DeleteDC(dc);
      EndPaint(hwnd, &ps); return 0;
    }
  }
  return DefWindowProc(hwnd, message, wparam, lparam);
}
}
void RegisterFloatingWindow(flutter::BinaryMessenger* messenger) {
  channel = std::make_unique<flutter::MethodChannel<Value>>(messenger,
      "vocalo1ng/floating", &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([](const flutter::MethodCall<Value>& call,
      std::unique_ptr<flutter::MethodResult<Value>> result) {
    const auto* args = call.arguments();
    const auto* data = args ? std::get_if<Map>(args) : nullptr;
    if (call.method_name() == "show" && data) {
      mode = static_cast<int>(Number(*data, "mode", 0));
      font_size = static_cast<int>(Number(*data, "size", 24));
      opacity = std::clamp(Number(*data, "opacity", .92), 0.0, 1.0);
      const auto argb = static_cast<uint32_t>(Number(*data,"color",4294967295.0));
      text_color=RGB((argb>>16)&255,(argb>>8)&255,argb&255);
      text_effect=static_cast<int>(Number(*data,"effect",0));
      font_face=static_cast<int>(Number(*data,"font",0));
      if (!floating) {
        WNDCLASSW wc{}; wc.lpfnWndProc = Procedure; wc.hInstance = GetModuleHandle(nullptr);
        wc.lpszClassName = L"Vocalo1ngFloatingLyrics"; wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
        RegisterClassW(&wc);
        floating = CreateWindowExW(WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_LAYERED,
            wc.lpszClassName, L"VOCALO1ng 悬浮歌词", WS_POPUP | WS_THICKFRAME,
            100, 100, 600, 240, nullptr, nullptr, wc.hInstance, nullptr);
      }
      if (!floating) { result->Success(Value(false)); return; }
      SetWindowLongPtr(floating,GWL_STYLE,WS_POPUP | (opacity == 0 ? 0 : WS_THICKFRAME));
      SetLayeredWindowAttributes(floating, RGB(1,0,1), opacity == 0 ? 255 : static_cast<BYTE>(opacity * 255), opacity == 0 ? LWA_COLORKEY : LWA_ALPHA);
      SetWindowPos(floating, HWND_TOPMOST, 0, 0, 600, mode == 5 ? 150 : 240,
          SWP_NOMOVE | SWP_NOACTIVATE | SWP_SHOWWINDOW | SWP_FRAMECHANGED);
      InvalidateRect(floating, nullptr, FALSE);
      result->Success(Value(true)); return;
    }
    if (call.method_name() == "update" && data) {
      original = Text(*data, "original"); translation = Text(*data, "translation");
      following = Text(*data, "next"); title = Text(*data, "title");
      progress = std::clamp(Number(*data, "progress", 0), 0.0, 1.0);
      const auto* value = Field(*data, "playing");
      playing = value && std::holds_alternative<bool>(*value) && std::get<bool>(*value);
      if (floating) InvalidateRect(floating, nullptr, FALSE);
      result->Success(); return;
    }
    result->NotImplemented();
  });
}
void CloseFloatingWindow() {
  if (floating) { DestroyWindow(floating); floating = nullptr; }
  channel.reset();
}
