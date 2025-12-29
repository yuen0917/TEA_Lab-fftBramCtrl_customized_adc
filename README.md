# FFT Related Modules

這份檔案包含了一些用於FFT的相關模塊，包括

- fft到bram的控制器
- 用於測試的adc模塊
- fft到Cordic的控制器

## FFT-BRAM-CTRL

這是一個用於將FFT的輸出數據寫入BRAM的控制器，它會透過AXI Stream接口接收FFT的輸出數據，並將其寫入BRAM

### 整體架構

- 使用AXI Stream接口接收FFT的輸出數據
- 將FFT的輸出數據寫入BRAM
- 會分成8個通道，每個通道的數據為256bit
- 每個通道的數據會分成實部和虛部，實部和虛部各為24bit，但會以32bit的形式寫入BRAM(最高的8bit為sign extension)
- 每次寫入address會增加4，寫入8次後，address會歸零

### 接口說明

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

### 版本和檔案說明

- fftBramCtrl: v1.0
    - 原本的版本(from 庠憲哥)
- fftBramCtrl_v2: v2.0
    - 重新設計狀態機
    - 新增了finish信號，用於通知外部已經完成256筆FFT的寫入
    - 新增了start信號，用於從外部重新啟動Controller
- fftBramCtrl_tb: 用於測試的測試檔案

## Customized ADC

這是一個用於將ADC的數據收集並轉換為32bit的數據，它會透過SPI接口接收ADC 24bit的數據，並將其轉換為32bit的數據，主要是測試用的模塊。這邊按照原本的程式碼寫法，一次讀取24bit的數據，而不是一次一個bit的讀取。

### 整體架構

- 使用SPI接口接收ADC的數據
- 將ADC的數據轉換為32bit的數據，最低8bit為0
- 每次轉換完一個通道的數據後，會發出flag_out信號，通知外部已經完成一個通道的轉換

### 接口說明

- clk: 時鐘信號
- rst: 重置信號
- sck: SPI時鐘信號
- ws: SPI的選擇信號
- sd: SPI的數據信號，24bit的數據
- start: 重新啟動模塊
- flag_in: 外部信號，用於通知模塊已經完成一次讀取
- data: 32bit的數據輸出
- flag_out: 通知外部已經完成一次讀取

### 版本和檔案說明

- customized_adc: v1.0
    - 原來的版本(from Michael)
- customized_adc_v2: v2.0
    - 資料輸出改為 `data_reg` + `assign data = data_reg`，避免 `.v` 下 output/net 與 reg 同名衝突
    - `data_reg` 加入 `(* keep = "true" *)`，利於 ILA/Debug 並避免綜合優化消除訊號
    - 握手協定明確化：
      - `flag_out=1` 表示 `data` 有效且保持不變
      - 偵測到 `flag_in` 下降緣視為外部 ack，模組清除 `flag_out` 並重置內部計數狀態
    - 防呆：在資料完成（bit_count==24）latch 當下，將 `bit_count/delay` 歸零，避免 bit_count 停留在 >24 造成下一筆無法產生

### 握手時序（建議外部使用方式）

1. 等待 `flag_out` 拉高（資料 ready）
2. 外部讀取 `data`
3. 外部送出一次 `flag_in` 的 high->low 變化作為 ack（需被 `sck` 取樣到）
4. 模組偵測到 `flag_in` 下降緣後清 `flag_out`，進入下一筆收集

### 限制

- 本模組假設 `sd` 為 24-bit 並行資料（非 I²S 1-bit 序列線）；若輸入為序列資料需先解串或改寫為 shift-register 接收方式。

## FFT-CORDIC-CTRL