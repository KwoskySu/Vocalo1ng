#include "audio_analysis.h"
#include "desktop_telemetry.h"
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
namespace {
using Value=flutter::EncodableValue;
std::unique_ptr<flutter::MethodChannel<Value>> channel;
}
void RegisterAudioAnalysis(flutter::BinaryMessenger* messenger) {
  channel=std::make_unique<flutter::MethodChannel<Value>>(messenger,"vocalo1ng/audio",&flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler([](const auto& call,auto result){
    auto& analyzer=SharedDesktopTelemetry();
    if(call.method_name()=="start"){analyzer.SetConsumer("visualizer",true,false);result->Success();return;}
    if(call.method_name()=="stop"){analyzer.SetConsumer("visualizer",false,false);result->Success();return;}
    if(call.method_name()=="read"){
      const auto data=analyzer.Read();flutter::EncodableList bands,wave;
      for(float b:data.bands)bands.emplace_back(static_cast<double>(b));
      for(float w:data.waveform)wave.emplace_back(static_cast<double>(w));
      result->Success(Value(flutter::EncodableMap{
        {Value("available"),Value(data.audio_available)},
        {Value("bands"),Value(bands)},{Value("waveform"),Value(wave)},
        {Value("status"),Value(data.audio_available?"当前歌曲 · 实时频谱":"等待本应用音频 · 需要 Windows 11 或更新的系统音频接口")}
      }));return;
    }result->NotImplemented();
  });
}
void CloseAudioAnalysis(){SharedDesktopTelemetry().SetConsumer("visualizer",false,false);channel.reset();}
