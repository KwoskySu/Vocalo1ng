#include "desktop_telemetry.h"
#include <windows.h>
#include <mmdeviceapi.h>
#include <audioclient.h>
#include <mmreg.h>
#include <pdh.h>
#include <pdhmsg.h>
#include <wbemidl.h>
#include <wrl/client.h>
#include <wrl/implements.h>
#include <audioclientactivationparams.h>
#include <powrprof.h>
#include <d3dkmthk.h>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <complex>
#include <cstring>
#include <map>
#include <string>
#include <vector>
using Microsoft::WRL::ComPtr;
namespace {
class AudioActivation final : public Microsoft::WRL::RuntimeClass<Microsoft::WRL::RuntimeClassFlags<Microsoft::WRL::ClassicCom>, IActivateAudioInterfaceCompletionHandler, Microsoft::WRL::FtmBase> {
 public:
  AudioActivation() : event(CreateEventW(nullptr,TRUE,FALSE,nullptr)) {}
  ~AudioActivation() { if(event) CloseHandle(event); }
  HRESULT STDMETHODCALLTYPE ActivateCompleted(IActivateAudioInterfaceAsyncOperation* op) override {
    ComPtr<IUnknown> unknown; HRESULT code=E_FAIL;
    const HRESULT get=op->GetActivateResult(&code,&unknown);
    if(SUCCEEDED(get)&&SUCCEEDED(code)) unknown.As(&client);
    SetEvent(event); return S_OK;
  }
  HANDLE event; ComPtr<IAudioClient> client;
};
ComPtr<IAudioClient> ProcessAudio(std::atomic<bool>& running) {
  AUDIOCLIENT_ACTIVATION_PARAMS params{};
  params.ActivationType=AUDIOCLIENT_ACTIVATION_TYPE_PROCESS_LOOPBACK;
  params.ProcessLoopbackParams.TargetProcessId=GetCurrentProcessId();
  params.ProcessLoopbackParams.ProcessLoopbackMode=PROCESS_LOOPBACK_MODE_INCLUDE_TARGET_PROCESS_TREE;
  PROPVARIANT prop{}; prop.vt=VT_BLOB; prop.blob.cbSize=sizeof(params); prop.blob.pBlobData=reinterpret_cast<BYTE*>(&params);
  auto completion=Microsoft::WRL::Make<AudioActivation>(); ComPtr<IActivateAudioInterfaceAsyncOperation> op;
  if(FAILED(ActivateAudioInterfaceAsync(VIRTUAL_AUDIO_DEVICE_PROCESS_LOOPBACK,__uuidof(IAudioClient),&prop,completion.Get(),&op)))return {};
  for(int i=0;i<60&&running;++i) if(WaitForSingleObject(completion->event,50)==WAIT_OBJECT_0)return completion->client;
  return {};
}
void GpuClocks(unsigned& core,unsigned& memory) {
  using Enumerate = NTSTATUS(APIENTRY*)(D3DKMT_ENUMADAPTERS2*);
  using Query = NTSTATUS(APIENTRY*)(D3DKMT_QUERYADAPTERINFO*);
  using Close = NTSTATUS(APIENTRY*)(D3DKMT_CLOSEADAPTER*);
  static HMODULE module=GetModuleHandleW(L"gdi32.dll");
  static auto enumerate=reinterpret_cast<Enumerate>(GetProcAddress(module,"D3DKMTEnumAdapters2"));
  static auto query=reinterpret_cast<Query>(GetProcAddress(module,"D3DKMTQueryAdapterInfo"));
  static auto close=reinterpret_cast<Close>(GetProcAddress(module,"D3DKMTCloseAdapter"));
  if(!enumerate||!query||!close)return;
  D3DKMT_ENUMADAPTERS2 adapters{}; if(enumerate(&adapters)<0||!adapters.NumAdapters||adapters.NumAdapters>32)return;
  std::vector<D3DKMT_ADAPTERINFO> info(adapters.NumAdapters);adapters.pAdapters=info.data();if(enumerate(&adapters)<0)return;
  for(const auto& adapter:info) {
    D3DKMT_ADAPTER_PERFDATA perf{}; perf.PhysicalAdapterIndex=0;
    D3DKMT_QUERYADAPTERINFO q{};q.hAdapter=adapter.hAdapter;q.Type=KMTQAITYPE_ADAPTERPERFDATA;q.pPrivateDriverData=&perf;q.PrivateDriverDataSize=sizeof(perf);
    if(query(&q)>=0)memory=std::max(memory,static_cast<unsigned>(perf.MemoryFrequency/1000000));
    D3DKMT_NODE_PERFDATA node{}; node.NodeOrdinal=0;node.PhysicalAdapterIndex=0;q.Type=KMTQAITYPE_NODEPERFDATA;q.pPrivateDriverData=&node;q.PrivateDriverDataSize=sizeof(node);
    if(query(&q)>=0)core=std::max(core,static_cast<unsigned>(node.Frequency/1000000));
    D3DKMT_CLOSEADAPTER c{};c.hAdapter=adapter.hAdapter;close(&c);
  }
}
constexpr size_t kFft = 1024;
constexpr double kPi = 3.141592653589793;
void FFT(std::array<std::complex<double>, kFft>& a) {
  for(size_t i=1,j=0;i<kFft;++i){size_t bit=kFft>>1;for(;j&bit;bit>>=1)j^=bit;j^=bit;if(i<j)std::swap(a[i],a[j]);}
  for(size_t len=2;len<=kFft;len<<=1){const auto root=std::polar(1.0,-2*kPi/len);for(size_t i=0;i<kFft;i+=len){std::complex<double> w=1;for(size_t j=0;j<len/2;++j){const auto u=a[i+j],v=a[i+j+len/2]*w;a[i+j]=u+v;a[i+j+len/2]=u-v;w*=root;}}}
}
uint64_t Time(const FILETIME& t){return (static_cast<uint64_t>(t.dwHighDateTime)<<32)|t.dwLowDateTime;}
unsigned MemoryClock(IWbemServices* services) {
  ComPtr<IEnumWbemClassObject> rows;
  BSTR language=SysAllocString(L"WQL"),query=SysAllocString(L"SELECT ConfiguredClockSpeed, Speed FROM Win32_PhysicalMemory");
  const HRESULT hr=services->ExecQuery(language,query,WBEM_FLAG_FORWARD_ONLY|WBEM_FLAG_RETURN_IMMEDIATELY,nullptr,&rows);
  SysFreeString(language);SysFreeString(query);if(FAILED(hr))return 0;
  unsigned clock=0;
  for(int i=0;i<16;++i){ComPtr<IWbemClassObject> row;ULONG returned=0;if(rows->Next(500,1,&row,&returned)!=S_OK||!returned)break;
    VARIANT value;VariantInit(&value);row->Get(L"ConfiguredClockSpeed",0,&value,nullptr,nullptr);
    unsigned n=value.vt==VT_I4?static_cast<unsigned>(std::max(0L,value.lVal)):value.vt==VT_UI4?value.ulVal:0;VariantClear(&value);
    if(!n){VariantInit(&value);row->Get(L"Speed",0,&value,nullptr,nullptr);n=value.vt==VT_I4?static_cast<unsigned>(std::max(0L,value.lVal)):value.vt==VT_UI4?value.ulVal:0;VariantClear(&value);}
    if(n)clock=clock?std::min(clock,n):n;
  }
  return clock;
}
}
DesktopTelemetry& SharedDesktopTelemetry(){static DesktopTelemetry instance;return instance;}
DesktopTelemetry::~DesktopTelemetry(){Stop();}
void DesktopTelemetry::SetConsumer(const std::string& key,bool audio,bool stats){
  if(audio||stats)consumers_[key]={audio,stats};else consumers_.erase(key);
  bool a=false,s=false;for(const auto& item:consumers_){a=a||item.second.first;s=s||item.second.second;}
  if(a||s)Start(a,s);else Stop();
}
void DesktopTelemetry::Start(bool audio,bool stats){audio_=audio;stats_=stats;if(running_.exchange(true))return;audio_thread_=std::thread(&DesktopTelemetry::CaptureAudio,this);stats_thread_=std::thread(&DesktopTelemetry::CaptureStats,this);}
void DesktopTelemetry::Stop(){running_=false;if(audio_thread_.joinable())audio_thread_.join();if(stats_thread_.joinable())stats_thread_.join();}
DesktopReadings DesktopTelemetry::Read(){std::lock_guard<std::mutex> guard(mutex_);return readings_;}
void DesktopTelemetry::CaptureAudio(){
  const HRESULT initialized=CoInitializeEx(nullptr,COINIT_MULTITHREADED);
  std::array<float,kFft> ring{};size_t head=0;
  while(running_){
    if(!audio_){std::this_thread::sleep_for(std::chrono::milliseconds(100));continue;}
    ComPtr<IAudioClient> client=ProcessAudio(running_); ComPtr<IAudioCaptureClient> capture;
    WAVEFORMATEX pcm{}; pcm.wFormatTag=WAVE_FORMAT_PCM;pcm.nChannels=2;pcm.nSamplesPerSec=48000;pcm.wBitsPerSample=16;pcm.nBlockAlign=4;pcm.nAvgBytesPerSec=192000;
    WAVEFORMATEX* format=&pcm;
    HRESULT hr=client?client->Initialize(AUDCLNT_SHAREMODE_SHARED,AUDCLNT_STREAMFLAGS_LOOPBACK,1000000,0,format,nullptr):E_FAIL;
    if(SUCCEEDED(hr))hr=client->GetService(IID_PPV_ARGS(&capture));
    if(SUCCEEDED(hr))hr=client->Start();
    if(FAILED(hr)||!format){{std::lock_guard<std::mutex> guard(mutex_);readings_.audio_available=false;readings_.bands.fill(0);readings_.waveform.fill(0);}for(int i=0;i<10&&running_;++i)std::this_thread::sleep_for(std::chrono::milliseconds(100));continue;}
    WORD tag=format->wFormatTag;
    if(tag==WAVE_FORMAT_EXTENSIBLE&&format->cbSize>=22)tag=static_cast<WORD>(reinterpret_cast<WAVEFORMATEXTENSIBLE*>(format)->SubFormat.Data1);
    const int bits=format->wBitsPerSample,channels=format->nChannels,bytes=bits/8;
    const bool supported=(tag==WAVE_FORMAT_IEEE_FLOAT&&bits==32)||(tag==WAVE_FORMAT_PCM&&(bits==16||bits==24||bits==32));
    auto last=std::chrono::steady_clock::now(),last_packet=last;
    while(running_&&audio_&&supported){
      UINT32 packet=0;if(FAILED(capture->GetNextPacketSize(&packet)))break;
      while(packet&&running_){BYTE* data=nullptr;UINT32 frames=0;DWORD flags=0;if(FAILED(capture->GetBuffer(&data,&frames,&flags,nullptr,nullptr)))break;
        for(UINT32 f=0;f<frames;++f){float sample=0;
          if(!(flags&AUDCLNT_BUFFERFLAGS_SILENT)&&data){for(int c=0;c<channels;++c){const BYTE* p=data+f*format->nBlockAlign+c*bytes;
            if(tag==WAVE_FORMAT_IEEE_FLOAT){float n;std::memcpy(&n,p,4);if(std::isfinite(n))sample+=n;}
            else if(bits==16){int16_t n;std::memcpy(&n,p,2);sample+=n/32768.f;}
            else if(bits==32){int32_t n;std::memcpy(&n,p,4);sample+=n/2147483648.f;}
            else {int32_t n=(static_cast<int32_t>(p[2])<<16)|(p[1]<<8)|p[0];if(n&0x800000)n|=~0xffffff;sample+=n/8388608.f;}
          }sample/=std::max(1,channels);}
          ring[head]=std::clamp(sample,-1.f,1.f);head=(head+1)%kFft;
        }
        if(frames)last_packet=std::chrono::steady_clock::now();
        capture->ReleaseBuffer(frames);if(FAILED(capture->GetNextPacketSize(&packet)))break;
      }
      const auto now=std::chrono::steady_clock::now();
      if(now-last_packet>std::chrono::milliseconds(180))ring.fill(0);
      if(now-last>=std::chrono::milliseconds(45)){
        std::array<std::complex<double>,kFft> spectrum{};
        for(size_t i=0;i<kFft;++i)spectrum[i]=ring[(head+i)%kFft]*(.5-.5*std::cos(2*kPi*i/(kFft-1)));
        FFT(spectrum);std::lock_guard<std::mutex> guard(mutex_);readings_.audio_available=true;
        for(size_t i=0;i<readings_.bands.size();++i){const double a=40*std::pow(std::min(20000.,format->nSamplesPerSec*.48)/40,i/48.0),b=40*std::pow(std::min(20000.,format->nSamplesPerSec*.48)/40,(i+1)/48.0);
          const size_t lo=std::clamp<size_t>(static_cast<size_t>(a*kFft/format->nSamplesPerSec),1,kFft/2-1),hi=std::clamp<size_t>(static_cast<size_t>(b*kFft/format->nSamplesPerSec),lo+1,kFft/2);
          double magnitude=0;for(size_t bin=lo;bin<hi;++bin)magnitude=std::max(magnitude,std::abs(spectrum[bin])/(kFft*.25));
          const float level=static_cast<float>(std::clamp((20*std::log10(std::max(magnitude,1e-8))+70)/70,0.,1.));readings_.bands[i]=std::max(level,readings_.bands[i]*.82f);
        }
        for(size_t i=0;i<readings_.waveform.size();++i)readings_.waveform[i]=ring[(head+i*kFft/readings_.waveform.size())%kFft];last=now;
      }
      std::this_thread::sleep_for(std::chrono::milliseconds(10));
    }
    client->Stop();
    {std::lock_guard<std::mutex> guard(mutex_);readings_.audio_available=false;readings_.bands.fill(0);}
    if(!supported)for(int i=0;i<10&&running_;++i)std::this_thread::sleep_for(std::chrono::milliseconds(100));
  }
  if(SUCCEEDED(initialized))CoUninitialize();
}
void DesktopTelemetry::CaptureStats(){
  const HRESULT initialized=CoInitializeEx(nullptr,COINIT_MULTITHREADED);
  PDH_HQUERY query=nullptr;PDH_HCOUNTER counter=nullptr;uint64_t prev_idle=0,prev_total=0;bool memory_read=false;
  while(running_){
    if(stats_){
      if(!memory_read){memory_read=true;ComPtr<IWbemLocator> locator;ComPtr<IWbemServices> services;
        if(SUCCEEDED(CoCreateInstance(CLSID_WbemLocator,nullptr,CLSCTX_INPROC_SERVER,IID_PPV_ARGS(&locator)))){BSTR ns=SysAllocString(L"ROOT\\CIMV2");const HRESULT hr=locator->ConnectServer(ns,nullptr,nullptr,nullptr,0,nullptr,nullptr,&services);SysFreeString(ns);
          if(SUCCEEDED(hr)){CoSetProxyBlanket(services.Get(),RPC_C_AUTHN_WINNT,RPC_C_AUTHZ_NONE,nullptr,RPC_C_AUTHN_LEVEL_CALL,RPC_C_IMP_LEVEL_IMPERSONATE,nullptr,EOAC_NONE);const auto clock=MemoryClock(services.Get());std::lock_guard<std::mutex> guard(mutex_);readings_.memory_clock=clock;}}
      }
      FILETIME idle,kernel,user;MEMORYSTATUSEX mem{};mem.dwLength=sizeof(mem);GlobalMemoryStatusEx(&mem);
      double cpu=-1;if(GetSystemTimes(&idle,&kernel,&user)){const auto total=Time(kernel)+Time(user),inactive=Time(idle);if(prev_total&&total>prev_total)cpu=std::clamp(100.*(1.-static_cast<double>(inactive-prev_idle)/(total-prev_total)),0.,100.);prev_total=total;prev_idle=inactive;}
      if(!query&&PdhOpenQueryW(nullptr,0,&query)==ERROR_SUCCESS){if(PdhAddEnglishCounterW(query,L"\\GPU Engine(*)\\Utilization Percentage",0,&counter)!=ERROR_SUCCESS)counter=nullptr;}
      double gpu=-1;
      if(query&&counter&&PdhCollectQueryData(query)==ERROR_SUCCESS){DWORD bytes=0,count=0;if(PdhGetFormattedCounterArrayW(counter,PDH_FMT_DOUBLE,&bytes,&count,nullptr)==PDH_MORE_DATA&&bytes<32*1024*1024){std::vector<BYTE> buffer(bytes);auto* values=reinterpret_cast<PDH_FMT_COUNTERVALUE_ITEM_W*>(buffer.data());if(PdhGetFormattedCounterArrayW(counter,PDH_FMT_DOUBLE,&bytes,&count,values)==ERROR_SUCCESS){std::map<std::wstring,double> engines;for(DWORD i=0;i<count;++i){if(values[i].FmtValue.CStatus!=ERROR_SUCCESS&&values[i].FmtValue.CStatus!=PDH_CSTATUS_NEW_DATA)continue;const std::wstring name=values[i].szName;const auto at=name.find(L"luid_");if(at!=std::wstring::npos)engines[name.substr(at)]+=std::max(0.,values[i].FmtValue.doubleValue);}for(const auto& e:engines)gpu=std::max(gpu,std::min(100.,e.second));}}}
      unsigned cpu_clock=0,gpu_clock=0,gpu_memory_clock=0;
      SYSTEM_INFO sys{};GetSystemInfo(&sys);struct CpuPower {ULONG number,max,current,limit,max_idle,current_idle;};
      std::vector<CpuPower> power(sys.dwNumberOfProcessors);
      if(CallNtPowerInformation(ProcessorInformation,nullptr,0,power.data(),static_cast<ULONG>(power.size()*sizeof(CpuPower)))==0)
        for(const auto& c:power)cpu_clock=std::max(cpu_clock,static_cast<unsigned>(c.current));
      GpuClocks(gpu_clock,gpu_memory_clock);
      std::lock_guard<std::mutex> guard(mutex_);readings_.cpu_clock=cpu_clock;readings_.gpu_clock=gpu_clock;readings_.gpu_memory_clock=gpu_memory_clock;readings_.cpu=cpu;readings_.gpu=gpu;readings_.ram_percent=mem.dwMemoryLoad;readings_.ram_total_gb=mem.ullTotalPhys/1073741824.0;readings_.ram_used_gb=(mem.ullTotalPhys-mem.ullAvailPhys)/1073741824.0;
    }
    for(int i=0;i<10&&running_;++i)std::this_thread::sleep_for(std::chrono::milliseconds(100));
  }
  if(query)PdhCloseQuery(query);if(SUCCEEDED(initialized))CoUninitialize();
}
