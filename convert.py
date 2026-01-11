"""
Generic base and bit-width converter.

功能說明（全部以 Python 實作）:
- 指定輸入的「進位」(base_in) 與「是否有號」(signed_in) 及「輸入 bit 數」(bits_in)
- 指定輸出的「進位」(base_out) 與「是否有號」(signed_out) 及「輸出 bit 數」(bits_out)
- 支援常見進位: 2, 8, 10, 16（也可擴充，只要輸入的字串能用 int(x, base_in) 解析）

例:
- 有號 10 進位 (bits_in=8) 轉成有號 2 進位 (bits_out=8)
- 無號 16 進位 (bits_in=12) 轉成有號 10 進位 (bits_out=16)
"""

from typing import Tuple
import sys
import argparse
import os


def _mask_for_bits(bits: int) -> int:
    """Return a bitmask with `bits` ones."""
    if bits <= 0:
        raise ValueError("bits must be positive")
    return (1 << bits) - 1


def _to_signed(value: int, bits: int) -> int:
    """Interpret `value` as signed two's complement with `bits` bits."""
    mask = _mask_for_bits(bits)
    value &= mask
    sign_bit = 1 << (bits - 1)
    if value & sign_bit:
        return value - (1 << bits)
    return value


def _to_unsigned(value: int, bits: int) -> int:
    """Interpret `value` as unsigned with `bits` bits (wrap by masking)."""
    mask = _mask_for_bits(bits)
    return value & mask


def parse_input(
    text: str,
    base_in: int,
    bits_in: int,
    signed_in: bool,
) -> int:
    """
    將輸入字串解析成「數學上的整數」(Python int)。

    - text: 輸入字串，例如 "15", "-3", "FF", "1010" 等
    - base_in: 輸入進位 (2/8/10/16 ...)
    - bits_in: 用多少 bits 來表示
    - signed_in: 輸入是否視為有號（使用二補數）

    回傳: Python 的 int，代表實際數學值。
    """
    # 先用 base_in 解析成暫時的整數（不含有號意義）
    raw = int(text, base_in)

    if signed_in:
        return _to_signed(raw, bits_in)
    else:
        return _to_unsigned(raw, bits_in)


def format_output(
    value: int,
    base_out: int,
    bits_out: int,
    signed_out: bool,
) -> str:
    """
    將「數學上的整數」轉成指定格式的字串。

    - value: Python int（已經是實際數學值）
    - base_out: 輸出進位
    - bits_out: 輸出 bit 數（決定飽和/截斷範圍）
    - signed_out: 輸出是否有號（用二補數）
    """
    # 先依照 signed_out 與 bits_out 把 value 限制在可表示範圍
    if signed_out:
        # 範圍: -2^(bits_out-1) ~ 2^(bits_out-1)-1
        min_v = -(1 << (bits_out - 1))
        max_v = (1 << (bits_out - 1)) - 1
        if value < min_v or value > max_v:
            # 超出範圍則以二補數 wrap（硬體常見作法）
            value = _to_signed(value, bits_out)
        # 真正要輸出的二補數 bit pattern（先轉成無號）
        unsigned_val = _to_unsigned(value, bits_out)
    else:
        # 範圍: 0 ~ 2^bits_out-1
        min_v = 0
        max_v = (1 << bits_out) - 1
        if value < min_v or value > max_v:
            # 超出範圍則截斷為無號 wrap
            value = _to_unsigned(value, bits_out)
        unsigned_val = value

    # 根據 base_out 輸出
    if base_out == 2:
        fmt = format(unsigned_val, f"0{bits_out}b")  # 固定位數補 0
    elif base_out == 8:
        # 八進位長度 = ceil(bits_out / 3)
        width = (bits_out + 2) // 3
        fmt = format(unsigned_val, f"0{width}o")
    elif base_out == 10:
        # 十進位若有號: 用簽名數字；若無號: 直接輸出無號值
        if signed_out:
            fmt = str(_to_signed(unsigned_val, bits_out))
        else:
            fmt = str(unsigned_val)
    elif base_out == 16:
        # 十六進位長度 = ceil(bits_out / 4)
        width = (bits_out + 3) // 4
        fmt = format(unsigned_val, f"0{width}X")  # 大寫
    else:
        # 一般進位: 不補零
        fmt = int_to_base(unsigned_val, base_out)

    return fmt


def int_to_base(value: int, base: int) -> str:
    """一般整數轉任意進位 (base >= 2)，不補零。"""
    if base < 2:
        raise ValueError("base must be >= 2")
    if value == 0:
        return "0"

    digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    negative = value < 0
    v = -value if negative else value
    res = []
    while v > 0:
        v, r = divmod(v, base)
        res.append(digits[r])
    res_str = "".join(reversed(res))
    return "-" + res_str if negative else res_str


def convert(
    text: str,
    base_in: int,
    bits_in: int,
    signed_in: bool,
    base_out: int,
    bits_out: int,
    signed_out: bool,
) -> str:
    """
    高階接口: 完成一次「輸入 -> 解析 -> 轉出」的流程。

    參數說明:
    - text:        輸入字串，例如 "15", "-3", "FF", "1010"
    - base_in:     輸入進位
    - bits_in:     輸入有效 bit 數
    - signed_in:   輸入是否有號（二補數）
    - base_out:    輸出進位
    - bits_out:    輸出 bit 數
    - signed_out:  輸出是否有號（二補數）
    """
    value = parse_input(text, base_in, bits_in, signed_in)
    return format_output(value, base_out, bits_out, signed_out)


def run_cli(argv: list[str] | None = None) -> None:
    """Command-line interface to call `convert` with arguments."""
    parser = argparse.ArgumentParser(
        description="Convert numbers between bases with configurable bit-width and signed/unsigned interpretation."
    )
    parser.add_argument(
        "text",
        nargs="?",
        help="input value string, e.g. '15', '-3', 'FF', '1010' (ignored if --input-file is used)",
    )
    parser.add_argument(
        "--input-file",
        type=str,
        help="path to a text file; each non-empty line is treated as an input value",
    )
    parser.add_argument(
        "--base-in",
        type=int,
        required=True,
        help="input base, e.g. 2, 8, 10, 16",
    )
    parser.add_argument(
        "--bits-in",
        type=int,
        required=True,
        help="number of bits used to represent the input",
    )
    parser.add_argument(
        "--signed-in",
        action="store_true",
        help="treat input as signed (two's complement). Default: unsigned",
    )
    parser.add_argument(
        "--base-out",
        type=int,
        required=True,
        help="output base, e.g. 2, 8, 10, 16",
    )
    parser.add_argument(
        "--bits-out",
        type=int,
        required=True,
        help="number of bits for output representation",
    )
    parser.add_argument(
        "--signed-out",
        action="store_true",
        help="treat output as signed (two's complement). Default: unsigned",
    )

    args = parser.parse_args(argv)
    if args.input_file:
        # Batch mode: read each line as one input value, also write to output file.
        base_name, ext = os.path.splitext(args.input_file)
        output_path = f"{base_name}_convert{ext}"
        with open(args.input_file, "r", encoding="utf-8") as f_in, open(
            output_path, "w", encoding="utf-8"
        ) as f_out:
            for line in f_in:
                value_str = line.strip()
                if not value_str:
                    continue  # skip empty lines
                result = convert(
                    text=value_str,
                    base_in=args.base_in,
                    bits_in=args.bits_in,
                    signed_in=args.signed_in,
                    base_out=args.base_out,
                    bits_out=args.bits_out,
                    signed_out=args.signed_out,
                )
                print(result)
                f_out.write(result + "\n")
    else:
        if args.text is None:
            parser.error("either provide <text> or use --input-file")
        result = convert(
            text=args.text,
            base_in=args.base_in,
            bits_in=args.bits_in,
            signed_in=args.signed_in,
            base_out=args.base_out,
            bits_out=args.bits_out,
            signed_out=args.signed_out,
        )
        print(result)


def print_help() -> None:
    """Print command-line usage help in English."""
    msg = """
Usage:
    python convert.py help
        Show this help message (short description).

    python convert.py <text> --base-in B1 --bits-in N1 [--signed-in] \\
                      --base-out B2 --bits-out N2 [--signed-out]
        Convert <text> from base B1 to base B2 with given bit-widths.

    (You can also import this module in Python and call `convert()` directly.)

Function `convert`:
    convert(
        text: str,       # input string, e.g. "15", "-3", "FF", "1010"
        base_in: int,    # input base, e.g. 2, 8, 10, 16
        bits_in: int,    # number of bits for input representation
        signed_in: bool, # whether input is signed (two's complement)
        base_out: int,   # output base, e.g. 2, 8, 10, 16
        bits_out: int,   # number of bits for output representation
        signed_out: bool # whether output is signed (two's complement)
    ) -> str

Examples:
    # signed decimal -3 (8 bits) to signed binary (8 bits)
    convert("-3", 10, 8, True, 2, 8, True)

    # unsigned hex FF (8 bits) to signed decimal (8 bits)
    convert("FF", 16, 8, False, 10, 8, True)
"""
    print(msg.strip())


def demo() -> None:
    """簡單示範一些典型用法。"""
    examples: Tuple[Tuple, str] = (
        (
            ("-3", 10, 8, True, 2, 8, True),
            "有號 10 進位 -3 (8bits) -> 有號 2 進位 (8bits)",
        ),
        (
            ("-3", 10, 8, True, 16, 8, False),
            "有號 10 進位 -3 (8bits) -> 無號 16 進位 (8bits)",
        ),
        (
            ("FF", 16, 8, False, 10, 8, True),
            "無號 16 進位 FF (8bits) -> 有號 10 進位 (8bits)",
        ),
        (
            ("1010", 2, 4, False, 10, 8, False),
            "無號 2 進位 1010 (4bits) -> 無號 10 進位 (8bits)",
        ),
    )

    for args, desc in examples:
        text, base_in, bits_in, signed_in, base_out, bits_out, signed_out = args
        out = convert(
            text=text,
            base_in=base_in,
            bits_in=bits_in,
            signed_in=signed_in,
            base_out=base_out,
            bits_out=bits_out,
            signed_out=signed_out,
        )
        print(f"{desc}: {text} -> {out}")


if __name__ == "__main__":
    # Command-line entry:
    # - "help": show custom short usage
    # - with other args: use argparse CLI
    # - no args: run demo
    if len(sys.argv) >= 2 and sys.argv[1].lower() == "help":
        print_help()
    elif len(sys.argv) >= 2:
        # pass all args except script name
        run_cli(sys.argv[1:])
    else:
        demo()


