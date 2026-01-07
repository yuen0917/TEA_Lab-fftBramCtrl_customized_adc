# FFT Related Modules

這份檔案包含了一些用於FFT的相關模塊，包括

- fft到bram的控制器
- 用於測試的adc模塊
- fft到Cordic的控制器

## 中文版本

### FFT-BRAM-CTRL

這是一個用於將FFT的輸出數據寫入BRAM的控制器，它會透過AXI Stream接口接收FFT的輸出數據，並將其寫入BRAM

#### 整體架構

- 使用AXI Stream接口接收FFT的輸出數據
- 將FFT的輸出數據寫入BRAM
- 會分成8個通道，每個通道的數據為256bit
- 每個通道的數據會分成實部和虛部，實部和虛部各為24bit，但會以32bit的形式寫入BRAM(最高的8bit為sign extension)
- 每次寫入address會增加4，寫入8次後，address會歸零

#### 接口說明

- clk: 時鐘信號
- rst_n: 重置信號
- s_axis_tdata: AXI Stream接口的數據信號
- s_axis_tvalid: AXI Stream接口的數據有效信號
- s_axis_tlast: AXI Stream接口的數據最後一個信號
- s_axis_tready: AXI Stream接口的數據準備好信號
- bram_addr: BRAM的地址信號
- bram_din_re: BRAM的實部數據信號
- bram_din_im: BRAM的虛部數據信號
- bram_we: BRAM的write enable信號
- bram_en: BRAM的enable信號
- bram_rst: BRAM的重置信號
- finish: 通知外部已經完成256筆FFT的寫入
- start: 重新啟動Controller

#### 版本和檔案說明

- fftBramCtrl: v1.0
    - 原本的版本(from 庠憲哥)
- fftBramCtrl_v2: v2.0
    - 重新設計狀態機
    - 新增了finish信號，用於通知外部已經完成256筆FFT的寫入
    - 新增了start信號，用於從外部重新啟動Controller
- fftBramCtrl_tb: 用於測試的測試檔案

### Customized ADC

這是一個用於將ADC的數據收集並轉換為32bit的數據，它會透過SPI接口接收ADC 24bit的數據，並將其轉換為32bit的數據，主要是測試用的模塊。這邊按照原本的程式碼寫法，一次讀取24bit的數據，而不是一次一個bit的讀取。

#### 整體架構

- 使用SPI接口接收ADC的數據
- 將ADC的數據轉換為32bit的數據，最低8bit為0
- 每次轉換完一個通道的數據後，會發出flag_out信號，通知外部已經完成一個通道的轉換

#### 接口說明

- clk: 時鐘信號
- rst: 重置信號
- sck: SPI時鐘信號
- ws: SPI的選擇信號
- sd: SPI的數據信號，24bit的數據
- start: 重新啟動模塊
- flag_in: 外部信號，用於通知模塊已經完成一次讀取
- data: 32bit的數據輸出
- flag_out: 通知外部已經完成一次讀取

#### 版本和檔案說明

- customized_adc: v1.0
    - 原來的版本(from Michael)
- customized_adc_v2: v2.0
    - 資料輸出改為 `data_reg` + `assign data = data_reg`，避免 `.v` 下 output/net 與 reg 同名衝突
    - `data_reg` 加入 `(* keep = "true" *)`，利於 ILA/Debug 並避免綜合優化消除訊號
    - 握手協定明確化：
      - `flag_out=1` 表示 `data` 有效且保持不變
      - 偵測到 `flag_in` 下降緣視為外部 ack，模組清除 `flag_out` 並重置內部計數狀態
    - 防呆：在資料完成（bit_count==24）latch 當下，將 `bit_count/delay` 歸零，避免 bit_count 停留在 >24 造成下一筆無法產生

#### 握手時序（建議外部使用方式）

1. 等待 `flag_out` 拉高（資料 ready）
2. 外部讀取 `data`
3. 外部送出一次 `flag_in` 的 high->low 變化作為 ack（需被 `sck` 取樣到）
4. 模組偵測到 `flag_in` 下降緣後清 `flag_out`，進入下一筆收集

#### 限制

- 本模組假設 `sd` 為 24-bit 並行資料（非 I²S 1-bit 序列線）；若輸入為序列資料需先解串或改寫為 shift-register 接收方式。

### FFT-CORDIC-CTRL

這是一個用於將 FFT 的輸出資料前半段（例如 512 點中的前 256 點）送往 CORDIC 的控制器。
主要透過 AXI Stream 介面接收 FFT（或寬度轉換模組）的輸出，並在維持正確握手與框架資訊（tlast）的前提下，只保留需要的樣本。

#### 整體架構

- 使用 AXI Stream 介面接收 FFT/寬度轉換模塊的輸出資料
- 僅保留 FFT 輸出的前半段（例如 512 點中的 0~255），捨棄後半段
- 將選出的資料以 AXI Stream 介面送往 CORDIC
- 根據保留長度重新產生對應的 `tlast`，讓 CORDIC 看到的是「截斷後的 frame」
- 在丟棄區間仍對上游回報 ready，避免 FFT 因為下游不需要資料而被阻塞

#### 介面說明（以 `fft2Cordic` 模組為例）

- aclk: 時鐘訊號
- aresetn: 低態有效重置信號
- s_axis_tdata: 上游 AXI Stream 輸入資料匯流排（例如 384bit，含多個複數通道）
- s_axis_tvalid: 上游 AXI Stream 資料有效訊號
- s_axis_tlast: 上游 frame 最後一拍訊號（例如 FFT 的第 511 筆）
- s_axis_tready: 回傳給上游的 ready 訊號
- m_axis_tdata: 輸出給 CORDIC 的資料（例如 48bit，單一複數樣本）
- m_axis_tvalid: 輸出給 CORDIC 的資料有效訊號
- m_axis_tlast: 輸出給 CORDIC 的 frame 結束訊號（例如在第 255 筆拉高）
- m_axis_tready: 來自 CORDIC 的 ready 訊號

#### 功能與設計重點

- 內部使用計數器追蹤 FFT 輸出樣本索引（例如 0~511）
- 透過比較樣本索引決定當前資料是否屬於「保留區」（前半段）或「丟棄區」（後半段）
- 只在保留區對 CORDIC 輸出 `tvalid`，並在保留區末端（例如索引 255）產生新的 `tlast`
- 在丟棄區 `s_axis_tready` 強制為 1'b1，讓 FFT 可以順利把剩餘資料吐完，不會被 CORDIC 壓回去

#### 版本和檔案說明

- fft2Cordic: v1.0 (from 庠憲哥)
    - 基本的 FFT → CORDIC AXI Stream 截斷/過濾控制器
    - 以 `fft2Cordic` 方式保留 FFT frame 的前半段樣本，並重新對應 `tlast`

## English Version

This repository contains several FFT-related modules:

- A controller that writes FFT output data into BRAM
- A customized ADC module for testing
- A controller that connects FFT output to a CORDIC module

### FFT-BRAM-CTRL

This module is a controller that writes FFT output data into BRAM.
It receives FFT output via an AXI Stream interface and stores the data into BRAM.

#### Architecture

- Receives FFT output data through an AXI Stream interface
- Writes FFT output data into BRAM
- Splits data into 8 channels, each channel is 256-bit wide
- Each channel contains real and imaginary parts, 24-bit each, but written into BRAM as 32-bit
  (upper 8 bits are sign extension)
- BRAM address increases by 4 on every write, and wraps back to 0 after 8 writes

#### Interface Description

- clk: clock signal
- rst_n: active-low reset signal
- s_axis_tdata: AXI Stream data bus from FFT
- s_axis_tvalid: AXI Stream data valid signal
- s_axis_tlast: AXI Stream end-of-frame signal
- s_axis_tready: AXI Stream ready signal
- bram_addr: BRAM address
- bram_din_re: BRAM data input (real part)
- bram_din_im: BRAM data input (imaginary part)
- bram_we: BRAM write enable
- bram_en: BRAM enable
- bram_rst: BRAM reset
- finish: indicates that 256 FFT samples have been written
- start: restart the controller from outside

#### Versions and Files

- fftBramCtrl: v1.0
    - Original version (from 庠憲哥)
- fftBramCtrl_v2: v2.0
    - Re-designed state machine
    - Added `finish` signal to indicate completion of 256 FFT writes
    - Added `start` signal to restart the controller from outside
- fftBramCtrl_tb: testbench for verification

### Customized ADC

This module collects ADC data and converts it into 32-bit words.
It receives 24-bit data from the ADC via an SPI-like interface and converts it to 32-bit
data, mainly for testing purposes. The implementation follows the original code style:
24 bits are read in one shot instead of bit-by-bit shifting.

#### Architecture

- Uses an SPI-like interface to receive ADC data
- Converts 24-bit ADC data into 32-bit output, with the lowest 8 bits set to 0
- After each channel is converted, the module asserts `flag_out` to notify the outside logic
  that one channel is ready

#### Interface Description

- clk: clock signal
- rst: reset signal
- sck: SPI clock
- ws: SPI word-select (chip-select) signal
- sd: SPI data input, 24-bit wide
- start: restart the module
- flag_in: external acknowledge signal, indicates one read cycle has completed
- data: 32-bit data output
- flag_out: indicates that one channel of data is ready

#### Versions and Files

- customized_adc: v1.0
    - Original version (from Michael)
- customized_adc_v2: v2.0
    - Changed output to `data_reg` + `assign data = data_reg` to avoid
      output/net vs. reg name conflicts in `.v`
    - Added `(* keep = "true" *)` attribute on `data_reg` to help ILA/Debug
      and prevent synthesis from optimizing the signal away
    - Clarified handshake protocol:
      - `flag_out = 1` means `data` is valid and stable
      - Detecting a falling edge on `flag_in` is treated as an external ack;
        the module clears `flag_out` and resets internal counters
    - Added safety handling: when data is latched at `bit_count == 24`,
      reset `bit_count/delay` to 0 to avoid staying at `>24` and blocking the next sample

#### Handshake Timing (Recommended Usage)

1. Wait for `flag_out` to go high (data is ready)
2. External logic reads `data`
3. External logic generates a high-to-low transition on `flag_in` as an ack
   (must be sampled by `sck`)
4. The module detects the falling edge on `flag_in`, clears `flag_out`,
   and starts collecting the next sample

#### Limitations

- Assumes `sd` is a 24-bit parallel data bus (not a 1-bit I²S serial line).
  If the input is serial, a deserializer or shift-register based receiver is required.

### FFT-CORDIC-CTRL

This module routes only the first half of the FFT output samples (e.g. 256 out of 512 points)
to a downstream CORDIC module.
It receives FFT (or width-converted) output through an AXI Stream interface and keeps only
the required samples, while preserving a correct handshake and frame boundary (`tlast`).

#### Architecture

- Receives FFT/width-converter output via AXI Stream
- Keeps only the first half of the FFT frame (e.g. indices 0–255 of 0–511), discarding the rest
- Sends the selected samples to the CORDIC via AXI Stream
- Regenerates `tlast` based on the kept length so that the CORDIC sees a truncated frame
- Continues to assert ready to the upstream source during the discard region to avoid stalling FFT

#### Interface Description (using `fft2Cordic` as example)

- aclk: clock signal
- aresetn: active-low reset signal
- s_axis_tdata: upstream AXI Stream data bus (e.g. 384-bit with multiple complex channels)
- s_axis_tvalid: upstream AXI Stream data valid
- s_axis_tlast: upstream end-of-frame signal (e.g. asserted on FFT sample index 511)
- s_axis_tready: ready signal back to the upstream FFT
- m_axis_tdata: data output to CORDIC (e.g. 48-bit, one complex sample)
- m_axis_tvalid: data valid output to CORDIC
- m_axis_tlast: end-of-frame signal to CORDIC (e.g. asserted on index 255)
- m_axis_tready: ready signal from CORDIC

#### Function and Design Highlights

- Uses an internal counter to track FFT sample indices (e.g. 0–511)
- Compares the current index against a threshold to decide whether the sample is in the
  keep region (first half) or discard region (second half)
- Asserts `m_axis_tvalid` only in the keep region and generates a new `m_axis_tlast`
  at the last kept sample (e.g. index 255)
- Forces `s_axis_tready` to `1'b1` in the discard region so FFT can flush the remaining
  samples without being back-pressured by CORDIC

#### Versions and Files

- fft2Cordic: v1.0 (from 庠憲哥)
    - Basic FFT → CORDIC AXI Stream truncation/filter controller
    - Keeps the first half of each FFT frame and regenerates `tlast` accordingly