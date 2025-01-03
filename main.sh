#!/bin/bash

# 获取脚本所在目录的绝对路径
SCRIPT_DIR=$(readlink -f $(dirname $0))

# 加载配置
source "$SCRIPT_DIR/config.sh"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 初始化日志
init_logging() {
    mkdir -p "$LOG_DIR"
    LOG_FILE="$LOG_DIR/mirror-$(date '+%Y%m%d-%H%M%S').log"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
}

# 日志函数
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "$timestamp $message"
}

# 检查必要的命令
check_requirements() {
    command -v git >/dev/null 2>&1 || error_exit "需要安装 git"
    command -v curl >/dev/null 2>&1 || error_exit "需要安装 curl"
    command -v jq >/dev/null 2>&1 || error_exit "需要安装 jq"
}

# 主函数
main() {
    init_logging
    check_requirements

    log "开始同步处理..."

    # 调用 mirror.sh 进行同步
    bash "$SCRIPT_DIR/mirror.sh" \
        "$GITHUB_USER" \
        "$GITHUB_TOKEN" \
        "$GITEA_URL" \
        "$GITEA_USER" \
        "$GITEA_TOKEN" \
        "$WORK_DIR" \
        "$SKIP_REPOS"

    mirror_exit_code=$?

    # 准备邮件内容
    summary="GitHub to Gitea 同步报告

运行时间: $(date '+%Y-%m-%d %H:%M:%S')
同步状态: $([ $mirror_exit_code -eq 0 ] && echo "成功" || echo "失败")

详细日志:
$(cat "${LOG_FILE}")"

    # 如果启用了邮件通知，调用 mail.sh
    if [ "$ENABLE_MAIL" = "true" ]; then
        subject="GitHub 同步$([ $mirror_exit_code -eq 0 ] && echo "成功" || echo "失败") - $(date '+%Y-%m-%d')"

        bash "$SCRIPT_DIR/mail.sh" \
            "$SMTP_SERVER" \
            "$SMTP_PORT" \
            "$SMTP_USER" \
            "$SMTP_PASS" \
            "$MAIL_TO" \
            "$MAIL_FROM" \
            "$subject" \
            "$summary"
    fi

    # 清理工作目录
    [ -d "$WORK_DIR" ] && rm -rf "$WORK_DIR"

    exit $mirror_exit_code
}

main "$@"