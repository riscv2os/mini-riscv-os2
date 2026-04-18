# Log

## [2026-04-08] Create mini-riscv-os wiki (Detailed Traditional Chinese)

### Ingest

- 建立了 `_wiki/` 目錄
- 閱讀並分析 9 個課程目錄的程式碼：01-HelloOs 到 09-InterruptISR
- 每個階段的程式碼包含：os.c, task.c, task.h, timer.c, mutex.c 等關鍵檔案

### Wiki Pages Created (Detailed Traditional Chinese)

使用繁體中文編寫，每個課程頁面約 300 行，包含：

1. **`index.md`** - 首頁和課程索引
2. **`01-hello-os.md`** - Hello OS 
   - 硬體環境 (QEMU virt, UART)
   - 啟動流程 (start.s)
   - C 語言核心 (os.c)
   - Linker Script
   - 編譯執行說明
   - 重要概念まとめ (RISC-V 特權等級, Hart vs Core, 記憶體映射 I/O)

3. **`02-context-switch.md`** - 上下文切換
   - 上下文原理和 Callee-saved 暫存器
   - sys.s 組合語言實現
   - os.c 任務管理
   - 執行流程分析
   - 重要概念まとめ

4. **`03-multi-tasking.md`** - 多任務
   - 合作式多任務原理
   - TCB 設計和任務創建
   - Round-Robin 排程
   - 執行流程詳細分析
   - 重要概念まとめ

5. **`04-timer-interrupt.md`** - 定時器中斷
   - RISC-V 中斷架構和 CSR
   - CLINT 詳解
   - 中斷處理機制
   - 程式碼實現
   - 重要概念まとめ

6. **`05-preemptive.md`** - 搶先式排程
   - 合作式 vs 搶先式比較
   - 時間片原理
   - 中斷觸發的上下文切換
   - 執行範例輸出
   - 重要概念まとめ

7. **`06-mutex.md`** - 互斥鎖
   - 競爭條件問題
   - 臨界區保護
   - mutex 實現 (使用 __sync_bool_compare_and_swap)
   - 使用範例
   - 重要概念まとめ

8. **`07-multicore-32bit.md`** - 32 位元多核心
   - RISC-V Hart 概念
   - 多核心初始化協調
   - 每個 hart 獨立排程
   - 跨核心同步
   - 重要概念まとめ

9. **`08-multicore-64bit.md`** - 64 位元多核心
   - rv64ima vs rv32ima
   - LP64 ABI
   - 工具鏈差異 (qemu-system-riscv64)
   - 程式碼修改
   - 重要概念まとめ

10. **`09-interrupt-isr.md`** - ISR 中斷系統
    - ISR 框架實現 (isr.h, isr.c)
    - 動態註冊
    - 分發機制
    - 使用範例
    - 專案總結

### Concept Pages

- **`risc-v-csrs.md`** - RISC-V CSR 暫存器參考
- **`risc-v-registers.md`** - RISC-V 暫存器約定

### Key Conventions

- Wiki 頁面使用 `[[wikilinks]]` 進行交叉引用
- 每個課程頁面包含：概述、程式碼實現、編譯執行、深入分析、概念まとめ
- 使用繁體中文，術語統一
- 每課約 300 行，內容詳細且完整

### Pattern Applied

- 遵循 LLM Wiki 模式 (https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)
- 建立 index.md 提供導航
- 每頁為獨立的課程摘要
- 保留 log.md 記錄 Wiki 演化
