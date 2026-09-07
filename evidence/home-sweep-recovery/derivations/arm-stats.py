import glob
import os
import re

print("arm\tpeak_vram_MiB\tpeak_gtt_MiB\tpeak_rss_MiB\tmin_avail_MiB\tswapin\tmax_temp_C\tsclk_selected\tmclk_selected\tsamples\tgfx_n\tgfx_p90_us\tgfx_max_us\tgfx_breaches")
for a in sorted(glob.glob("arms/*/")):
    vram = gtt = rss = temp = 0
    avail = 10 ** 12
    swap = 0
    sclk = set()
    mclk = set()
    n = 0
    for l in open(a + "telemetry.log"):
        if not l.startswith("sample_utc="):
            continue
        n += 1
        head = l.split(" sclk=")[0]
        kv = dict(re.findall(r"(\w+)=(\S+)", head))
        vram = max(vram, int(kv.get("vram_used_bytes", 0)))
        gtt = max(gtt, int(kv.get("gtt_used_bytes", 0)))
        rss = max(rss, int(kv.get("peak_rss_kib", 0)))
        avail = min(avail, int(kv.get("mem_available_kib", 10 ** 12)))
        swap += int(kv.get("swapin_bytes", 0))
        temp = max(temp, int(kv.get("max_temp_millicelsius", 0)))
        m = re.search(r"sclk=(.*?) mclk=(.*?)$", l.strip())
        s = re.search(r"(\d+)Mhz \*", m.group(1))
        k = re.search(r"(\d+)Mhz \*", m.group(2))
        if s:
            sclk.add(int(s.group(1)))
        if k:
            mclk.add(int(k.group(1)))
    el = []
    br = 0
    for l in open(a + "graphics-latency.log"):
        if l.startswith("sample "):
            kv = dict(re.findall(r"(\w+)=(\S+)", l))
            el.append(int(kv.get("elapsed_us", 0)))
            if int(kv.get("result", 0)) != 0 or int(kv.get("elapsed_us", 0)) > 20000:
                br += 1
    el.sort()
    p90 = el[int(0.9 * (len(el) - 1))] if el else 0
    name = os.path.basename(a.rstrip("/"))
    print(f"{name}\t{vram / 2 ** 20:.0f}\t{gtt / 2 ** 20:.0f}\t{rss / 1024:.0f}\t{avail / 1024:.0f}\t{swap}\t{temp / 1000:.1f}\t{sorted(sclk)}\t{sorted(mclk)}\t{n}\t{len(el)}\t{p90}\t{max(el) if el else 0}\t{br}")
