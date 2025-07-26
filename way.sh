#!/bin/bash

# 强制加载用户环境（关键修复）
source ~/.bashrc 2>/dev/null
source ~/.profile 2>/dev/null

# 设置代理
export http_proxy="http://127.0.0.1:7890"
export https_proxy="http://127.0.0.1:7890"

# 检查参数
if [ $# -eq 0 ]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

DOMAIN=$1
OUTPUT_DIR="${DOMAIN%%.*}_out"
mkdir -p "$OUTPUT_DIR"

# 环境验证
echo -e "\n\033[32m[+] 环境验证:\033[0m"
echo "PATH: $PATH"
echo "waymore路径: $(which waymore)"
echo "当前用户: $(whoami)"

# 增强型执行函数
run_cmd() {
    echo -e "\n\033[34m[→] 执行: $1\033[0m"
    echo "[命令] ${2}"
    
    # 特殊处理kiterunner
    if [[ "$1" == "kiterunner" ]]; then
        /bin/bash -c "${2}"
        [ -f "$OUTPUT_DIR/kr_out.txt" ] && cat "$OUTPUT_DIR/kr_out.txt" >> "$OUTPUT_DIR/${1}_out.txt"
    else
        /bin/bash -c "${2}" > "$OUTPUT_DIR/${1}_out.txt" 2>&1
    fi
    
    if [ $? -eq 0 ]; then
        echo -e "\033[32m[✓] 成功\033[0m"
    else
        echo -e "\033[31m[×] 失败 (代码: $?)\033[0m"
        echo "最后5行输出:"
        tail -n 5 "$OUTPUT_DIR/${1}_out.txt"
    fi
}

# 主执行流程
run_cmd "waymore" "waymore -i $DOMAIN -mode U -mc 200,403,302 -v"
run_cmd "hakrawler" "echo http://$DOMAIN | hakrawler -subs"
run_cmd "katana" "katana -u $DOMAIN -sc -ef woff,css,png -jc -c 50"
run_cmd "gospider" "gospider -s http://$DOMAIN -c 50 -d 2 | grep -E '\[(code|href|javascript|from)\]' | grep -oP '(?<=\] - ).*|(?<=\[from: )https?://[^]]+' | sort -u"
run_cmd "gau" "gau --proxy http://127.0.0.1:7890 $DOMAIN"
run_cmd "waybackurls" "waybackurls $DOMAIN"
run_cmd "paramspider" "paramspider -d $DOMAIN --proxy 127.0.0.1:7890 && { [ -d results ] && cat results/* > $OUTPUT_DIR/paramspider_out.txt; rm -rf results; }"
run_cmd "kiterunner" "kr scan $DOMAIN -w /root/tools/kiterunner/routes-small.kite -x 5 -j 100 -o $OUTPUT_DIR/kr_out.txt"

# 结果处理
echo -e "\n\033[32m[+] 合并结果...\033[0m"
grep -ahE "https?://[^/]*$DOMAIN[^/]*/" $OUTPUT_DIR/*_out.txt 2>/dev/null \
    | grep -avE "https?://[^/]*\..+$DOMAIN[^/]*/" \
    | sort -u > "$OUTPUT_DIR/final_urls.txt"

echo -e "\n\033[32m[√] 完成! \033[0m"

