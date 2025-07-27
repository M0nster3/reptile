#!/bin/bash

# 强制加载用户环境（关键修复）
source ~/.bashrc 2>/dev/null
source ~/.profile 2>/dev/null

# 设置代理
export http_proxy="http://127.0.0.1:7890"
export https_proxy="http://127.0.0.1:7890"
source ~/venv/bin/activate
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
        [ -f "$OUTPUT_DIR/kiterunner_out.txt" ] && cat "$OUTPUT_DIR/kiterunner_out.txt" >> "$OUTPUT_DIR/${1}_out.txt"
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
run_cmd "kiterunner" "kr scan $DOMAIN -w /root/tools/kiterunner/routes-small.kite -x 5 -j 100 -o $OUTPUT_DIR/kiterunner_out.txt"

# 合并结果函数（修复版）
# 优化的合并结果函数
#!/bin/bash

# [...] (保留之前的代码直到merge_results函数)

merge_results() {
    echo -e "\n\033[32m[+] 合并并过滤结果...\033[0m"
    
    # 第一步：收集并标准化所有URL
    cat "$OUTPUT_DIR"/*_out.txt 2>/dev/null | grep -aEo "((https?:)?//)?[^ ]*" | \
    grep -i "$DOMAIN" | \
    sed -E '
        s|^(https?:)?//|https://|;
        s|^([^/])|https://\1|;
        s|https://https://|https://|g;
        s|http://https://|https://|g;
    ' | \
    # 关键过滤：只保留主域名和www子域名
    grep -aE "https?://(www\.)?$DOMAIN([/:]|$)" | \
    # 清理无效内容
    sed '
        /https*:\/\/[^ ]*https*:\/\/.*/d;
        /^$/d
    ' | sort -u > "$OUTPUT_DIR/final_urls.txt"
    
    # 结果验证
    if [ -s "$OUTPUT_DIR/final_urls.txt" ]; then
        echo -e "\033[32m[√] 找到 $(wc -l < "$OUTPUT_DIR/final_urls.txt") 个有效URL\033[0m"
    else
        echo -e "\033[31m[×] 未找到有效URL\033[0m"
        echo -e "\033[33m[调试] 请检查工具原始输出:\033[0m"
        ls -la "$OUTPUT_DIR"/*_out.txt
    fi
}

merge_results
