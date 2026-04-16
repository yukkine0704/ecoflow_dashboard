from pathlib import Path
from email import policy
from email.parser import BytesParser
import html
import re
import sys


def extract_to_text(mhtml_path: Path, output_path: Path) -> None:
    msg = BytesParser(policy=policy.default).parsebytes(mhtml_path.read_bytes())
    html_part = None

    if msg.is_multipart():
        for part in msg.walk():
            if part.get_content_type() == "text/html":
                html_part = part
                break
    else:
        html_part = msg

    if html_part is None:
        raise RuntimeError(f"No text/html part found in: {mhtml_path}")

    body = html_part.get_payload(decode=True)
    if body is None:
        body = html_part.get_content().encode("utf-8", "ignore")
    html_str = body.decode("utf-8", errors="ignore")

    html_str = re.sub(r"<script[\s\S]*?</script>", " ", html_str, flags=re.I)
    html_str = re.sub(r"<style[\s\S]*?</style>", " ", html_str, flags=re.I)
    html_str = re.sub(
        r"</(p|div|li|h1|h2|h3|h4|tr|td|th|section|article|br)>",
        "\n",
        html_str,
        flags=re.I,
    )
    text = re.sub(r"<[^>]+>", " ", html_str)
    text = html.unescape(text)
    text = re.sub(r"[ \t\r\f\v]+", " ", text)
    text = re.sub(r"\n+", "\n", text)
    text = "\n".join(line.strip() for line in text.splitlines() if line.strip())

    output_path.write_text(text, encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 3:
        print("Usage: python extract_mhtml.py <input.mhtml> <output.txt>")
        return 1

    input_path = Path(sys.argv[1])
    output_path = Path(sys.argv[2])
    extract_to_text(input_path, output_path)
    print(f"Wrote: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

