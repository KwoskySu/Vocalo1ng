#include "../windows/runner/desktop_telemetry.h"
#include <chrono>
#include <iostream>
#include <thread>
// Headless, read-only check. Does not play sound, inspect processes or open UI.
int main() {
  DesktopTelemetry telemetry;
  telemetry.Start(true, true);
  std::this_thread::sleep_for(std::chrono::seconds(4));
  const auto data = telemetry.Read();
  telemetry.Stop();
  std::cout << "cpu=" << data.cpu << " gpu=" << data.gpu
            << " ram_percent=" << data.ram_percent << " ram_gb=" << data.ram_total_gb
            << " configured_memory=" << data.memory_clock
            << " cpu_mhz=" << data.cpu_clock << " gpu_mhz=" << data.gpu_clock << " vram_mhz=" << data.gpu_memory_clock
            << " loopback_available=" << data.audio_available << "\n";
  return data.cpu < 0 || data.cpu > 100 || data.gpu > 100 || data.ram_total_gb <= 0 || data.ram_percent > 100 ? 1 : 0;
}
