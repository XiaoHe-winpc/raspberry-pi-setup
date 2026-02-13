#!/bin/bash
# ============================================================================
# 树莓派智能优化脚本 v3.6.0
# 作者：小何-winp电脑（XiaoHe_winpc）
# 功能：硬件验机 + 系统优化 + 中文支持 + 性能测试 + 智能超频 + 温度监控
#       + 智能选源（对比多个镜像延迟，自动选用最快）
# 特点：1. 全自动模式（输入A） | 2. 交互模式
#       3. 全自动模式下智能判断是否安装中文支持
#       4. 新增智能超频与综合性能优化选项
#       5. 新增硬件兼容性检查与温度监控
#       6. 新增智能测速选源（v3.6.0）
# 使用方法：sudo bash v3.6.sh
# ============================================================================

# 颜色定义
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
PURPLE='\033[1;35m'
NC='\033[0m' # No Color

# ============================================================================
# 全局变量
# ============================================================================
ACTUAL_USER=${SUDO_USER:-$(logname 2>/dev/null || echo "pi")}
REPORT_DATA=""
AUTO_MODE=false
IS_IN_CHINA=false
SKIP_CHINESE=false
USER_CHOICE=""
PERFORMANCE_MODE=false
OVERCLOCK_LEVEL=0  # 0=不超频, 1=保守, 2=平衡, 3=激进
TEMP_DIR="/tmp/pi_optimizer"
LOG_FILE="$HOME/pi_optimizer_$(date +%Y%m%d_%H%M%S).log"
UNDERVOLT_DETECTED=false
RASPI_MODEL="Unknown"
RASPI_REVISION="Unknown"

# ============================================================================
# 工具函数
# ============================================================================

init_environment() {
    mkdir -p "$TEMP_DIR"
    exec 2> >(tee -a "$LOG_FILE")
    log_message "脚本启动 - 树莓派优化脚本 v3.6.0"
    
    # 确保必要工具已安装
    if ! command -v bc &> /dev/null; then
        apt update -y && apt install -y bc
    fi
    if ! command -v curl &> /dev/null; then
        apt update -y && apt install -y curl
    fi
}

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

print_header() {
    clear
    echo -e "${CYAN}"
    echo "================================================"
    echo "      树莓派智能优化与验机脚本 v3.6.0"
    echo "================================================"
    echo -e "${NC}"
    echo -e "${PURPLE}新增特性：智能超频 + 综合性能优化 + 温度监控 + 智能选源${NC}"
    echo ""
    echo "模式选择："
    echo "  1. 全自动模式 - 输入 ${GREEN}A${NC}（推荐新手）"
    echo "  2. 交互模式   - 直接按 ${GREEN}Enter${NC}（高级用户）"
    echo "================================================"
    echo ""
    local user_choice
    read -p "请选择运行模式: " -n 1 user_choice
    echo ""
    
    if [[ "$user_choice" == "A" || "$user_choice" == "a" ]]; then
        AUTO_MODE=true
        echo -e "${GREEN}已启用全自动模式！${NC}"
        log_message "启用全自动模式"
        echo -e "${YELLOW}注意：全自动模式将自动执行基础优化，并启用平衡超频（1950MHz）。${NC}"
        sleep 2
    else
        AUTO_MODE=false
        echo -e "${YELLOW}使用交互模式，每个步骤将请求确认。${NC}"
        log_message "启用交互模式"
    fi
    sleep 1
}

print_step() {
    echo -e "\n${GREEN}>>> ${1}${NC}"
    log_message "开始步骤: $1"
}

print_info() {
    echo -e "${BLUE}  ℹ ${1}${NC}"
    log_message "信息: $1"
}

print_success() {
    echo -e "${GREEN}  ✓ ${1}${NC}"
    log_message "成功: $1"
}

print_warning() {
    echo -e "${YELLOW}  ⚠ ${1}${NC}"
    log_message "警告: $1"
}

print_error() {
    echo -e "${RED}  ✗ ${1}${NC}"
    log_message "错误: $1"
}

add_to_report() {
    REPORT_DATA="${REPORT_DATA}${1}\n"
}

# ============================================================================
# 【v3.6.0】智能测速：对比多个镜像源延迟，返回最快镜像URL
# ============================================================================
detect_best_mirror() {
    print_step "智能测速：寻找最快镜像源"
    
    # 国内主流镜像源列表（debian 源地址格式）
    local -A MIRRORS=(
        ["清华大学"]="mirrors.tuna.tsinghua.edu.cn"
        ["中科大"]="mirrors.ustc.edu.cn"
        ["阿里云"]="mirrors.aliyun.com"
        ["华为云"]="mirrors.huaweicloud.com"
        ["腾讯云"]="mirrors.tencent.com"
        ["网易"]="mirrors.163.com"
        ["搜狐"]="mirrors.sohu.com"
    )
    
    local best_mirror="mirrors.tuna.tsinghua.edu.cn"  # 默认清华
    local best_time=999999
    local results=()
    
    # 检查依赖
    if ! command -v curl &> /dev/null; then
        print_warning "curl 未安装，无法测速，将使用默认清华源"
        apt install -y curl || print_error "curl 安装失败，使用默认源"
        return 1
    fi
    
    echo -e "\n${CYAN}正在测试各镜像源延迟...${NC}"
    
    for name in "${!MIRRORS[@]}"; do
        local url="${MIRRORS[$name]}"
        local total_time=0
        local success_count=0
        
        # 测速3次取平均值
        for i in {1..3}; do
            local time=$(curl -o /dev/null -s -w '%{time_total}' \
                --connect-timeout 3 --max-time 5 \
                "http://$url/debian/dists/stable/Release" 2>/dev/null || echo "0")
            
            if [ "$(echo "$time > 0" | bc)" -eq 1 ]; then
                total_time=$(echo "$total_time + $time" | bc)
                success_count=$((success_count + 1))
            fi
        done
        
        if [ $success_count -gt 0 ]; then
            local avg_time=$(echo "scale=3; $total_time / $success_count" | bc)
            results+=("$name: ${avg_time}s")
            
            if [ "$(echo "$avg_time < $best_time" | bc)" -eq 1 ]; then
                best_time=$avg_time
                best_mirror=$url
                print_success "$name 延迟 ${avg_time}s (当前最快)"
            else
                print_info "$name 延迟 ${avg_time}s"
            fi
        else
            print_warning "$name 连接失败，跳过"
        fi
    done
    
    echo ""
    print_success "最快镜像源: $best_mirror (延迟 ${best_time}s)"
    add_to_report "智能选源: 最快镜像为 ${best_mirror} (${best_time}s)"
    
    echo "$best_mirror"
}

# ============================================================================
# 网络环境智能检测
# ============================================================================
detect_network_environment() {
    print_step "检测网络环境"
    local china_ip_pattern='^(1\.|14\.|27\.|36\.|39\.|42\.|49\.|59\.|101\.|103\.|106\.|110\.|111\.|112\.|113\.|114\.|115\.|116\.|117\.|118\.|119\.|120\.|121\.|122\.|123\.|124\.|125\.|126\.|169\.|175\.|180\.|182\.|183\.|202\.|203\.|210\.|211\.|218\.|219\.|220\.|221\.|222\.|223\.)'
    local ip=$(curl -s --connect-timeout 3 http://ipinfo.io/ip 2>/dev/null || echo "")
    if [[ $ip =~ $china_ip_pattern ]]; then
        IS_IN_CHINA=true
        print_info "检测到中国网络环境，将使用国内镜像源并安装中文支持"
    else
        IS_IN_CHINA=false
        print_info "检测为非中国网络环境，将使用默认官方源"
    fi
    echo "IS_IN_CHINA=$IS_IN_CHINA" > /tmp/network_env
    add_to_report "网络环境: $([ "$IS_IN_CHINA" = true ] && echo "中国" || echo "海外")"
}

# ============================================================================
# 配置软件源 - 智能选择最快镜像（v3.6.0）
# ============================================================================
configure_sources() {
    print_step "配置软件源"
    
    # 读取网络环境检测结果
    if [ -f /tmp/network_env ]; then
        source /tmp/network_env
    else
        detect_network_environment
        source /tmp/network_env
    fi
    
    # 备份原始源文件
    local backup_time=$(date +%Y%m%d_%H%M%S)
    [ -f /etc/apt/sources.list ] && sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup.$backup_time
    [ -f /etc/apt/sources.list.d/raspi.list ] && sudo cp /etc/apt/sources.list.d/raspi.list /etc/apt/sources.list.d/raspi.list.backup.$backup_time
    
    local MIRROR_DOMAIN=""
    
    if [ "$IS_IN_CHINA" = true ]; then
        print_info "检测到中国网络环境，将智能选择最快镜像源"
        
        if [ "$AUTO_MODE" = false ]; then
            read -p "是否测试多个镜像源并自动选用最快源？(y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                MIRROR_DOMAIN=$(detect_best_mirror)
            else
                print_info "跳过测速，使用默认清华源"
                MIRROR_DOMAIN="mirrors.tuna.tsinghua.edu.cn"
            fi
        else
            print_info "全自动模式：自动测速并选用最快镜像"
            MIRROR_DOMAIN=$(detect_best_mirror)
        fi
        
        if [ -z "$MIRROR_DOMAIN" ]; then
            print_warning "测速失败，使用默认清华源"
            MIRROR_DOMAIN="mirrors.tuna.tsinghua.edu.cn"
        fi
        
        print_info "设置镜像源: $MIRROR_DOMAIN"
        
        sudo sed -i "s|deb.debian.org/debian|$MIRROR_DOMAIN/debian|g" /etc/apt/sources.list
        sudo sed -i "s|security.debian.org/debian-security|$MIRROR_DOMAIN/debian-security|g" /etc/apt/sources.list
        
        if [ -f /etc/apt/sources.list.d/raspi.list ]; then
            sudo sed -i "s|archive.raspberrypi.org/debian|$MIRROR_DOMAIN/raspberrypi|g" /etc/apt/sources.list.d/raspi.list
        fi
        
        add_to_report "软件源: 智能选择 ($MIRROR_DOMAIN)"
        print_success "已配置最快镜像源: $MIRROR_DOMAIN"
    else
        print_info "Using default Raspberry Pi OS sources (non-China environment)"
        add_to_report "软件源: 默认官方源"
    fi
    
    print_success "软件源配置完成"
}

# ============================================================================
# 硬件兼容性检查
# ============================================================================
check_hardware_compatibility() {
    print_step "检查硬件兼容性"
    
    RASPI_MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "Unknown")
    RASPI_REVISION=$(cat /proc/device-tree/model | rev | cut -d ' ' -f 1 | rev 2>/dev/null || echo "Unknown")
    
    echo "  检测到型号: $RASPI_MODEL"
    echo "  硬件版本: Rev $RASPI_REVISION"
    
    if [[ "$RASPI_MODEL" == *"Raspberry Pi Zero"* ]]; then
        print_warning "树莓派 Zero 型号性能有限，不建议超频"
        if [ "$OVERCLOCK_LEVEL" -gt 1 ]; then
            OVERCLOCK_LEVEL=1
        fi
    elif [[ "$RASPI_MODEL" == *"Raspberry Pi 1"* ]] || [[ "$RASPI_MODEL" == *"Model A"* ]] || [[ "$RASPI_MODEL" == *"Model B"* ]]; then
        print_warning "旧款树莓派（1代）超频能力有限，建议谨慎操作"
        if [ "$OVERCLOCK_LEVEL" -gt 2 ]; then
            OVERCLOCK_LEVEL=2
        fi
    elif [[ "$RASPI_MODEL" == *"Raspberry Pi 2"* ]]; then
        print_info "树莓派 2 型号支持中等超频"
    elif [[ "$RASPI_MODEL" == *"Raspberry Pi 3"* ]]; then
        print_info "树莓派 3 型号支持较好的超频"
    elif [[ "$RASPI_MODEL" == *"Raspberry Pi 4"* ]]; then
        print_info "树莓派 4 型号支持优秀的超频性能"
    elif [[ "$RASPI_MODEL" == *"Raspberry Pi 5"* ]]; then
        print_info "树莓派 5 型号支持最新的超频功能"
    else
        print_warning "未知型号，超频功能可能受限"
    fi
    
    echo "RASPI_MODEL='$RASPI_MODEL'" > "$TEMP_DIR/raspi_info"
    echo "RASPI_REVISION='$RASPI_REVISION'" >> "$TEMP_DIR/raspi_info"
    
    add_to_report "=== 硬件兼容性检查 ==="
    add_to_report "型号: $RASPI_MODEL"
    add_to_report "版本: Rev $RASPI_REVISION"
}

# ============================================================================
# 电源检测函数
# ============================================================================
check_power_supply() {
    print_step "检测电源状态"
    
    if ! command -v vcgencmd &> /dev/null; then
        print_warning "vcgencmd 命令未找到，跳过电源检测"
        add_to_report "电源检测: ⚠ 工具未安装"
        return 1
    fi
    
    local throttled=$(vcgencmd get_throttled)
    local undervolt=$(vcgencmd get_throttled | cut -d'=' -f2)
    undervolt=${undervolt:-0}
    
    echo "  电源状态: $throttled"
    
    if [ $((undervolt & 0x1)) -eq 1 ]; then
        print_error "检测到电源欠压！"
        UNDERVOLT_DETECTED=true
        add_to_report "电源状态: ✗ 欠压警告"
    else
        print_success "电源电压正常"
        add_to_report "电源状态: ✓ 正常"
    fi
    
    if [ $((undervolt & 0x2)) -eq 2 ]; then
        print_warning "检测到频率限制（可能由于高温或欠压）"
        add_to_report "频率状态: ⚠ 受限"
    fi
    if [ $((undervolt & 0x4)) -eq 4 ]; then
        print_warning "检测到CPU频率限制"
        add_to_report "CPU频率: ⚠ 受限"
    fi
    if [ $((undervolt & 0x8)) -eq 8 ]; then
        print_warning "检测到温度限制（温度过高）"
        add_to_report "温度状态: ⚠ 过高"
    fi
    
    if [ "$UNDERVOLT_DETECTED" = true ] && [ "$AUTO_MODE" = false ]; then
        echo -e "\n${YELLOW}电源欠压可能导致系统不稳定，特别是超频时！${NC}"
        read -p "是否继续优化？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "用户选择退出"
            exit 1
        fi
    elif [ "$UNDERVOLT_DETECTED" = true ]; then
        print_warning "全自动模式检测到欠压，但将继续执行"
    fi
    
    return 0
}

# ============================================================================
# 硬件信息检测
# ============================================================================
detect_hardware() {
    print_step "硬件信息检测"
    
    local MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "Unknown")
    local SERIAL=$(cat /proc/cpuinfo | grep Serial | cut -d ' ' -f 2 2>/dev/null || echo "Unknown")
    local MEMORY=$(vcgencmd get_config total_mem | cut -d '=' -f 2 2>/dev/null || echo "0")
    local REVISION=$(cat /proc/device-tree/model | rev | cut -d ' ' -f 1 | rev 2>/dev/null || echo "Unknown")
    
    local CPU_MODEL=$(grep -m1 "Model" /proc/cpuinfo | cut -d ':' -f2 | sed 's/^ //')
    [ -z "$CPU_MODEL" ] && CPU_MODEL=$(grep -m1 "Hardware" /proc/cpuinfo | cut -d ':' -f2 | sed 's/^ //')
    local CPU_CORES=$(nproc)
    
    local TEMP="0"
    if command -v vcgencmd &> /dev/null; then
        TEMP=$(vcgencmd measure_temp | cut -d '=' -f 2 | cut -d "'" -f 1 2>/dev/null || echo "0")
    else
        TEMP=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "%.1f", $1/1000}' || echo "0")
    fi
    
    echo "  主板型号: $MODEL"
    echo "  硬件版本: Rev $REVISION"
    echo "  内存总量: $((MEMORY / 1024)) MB"
    echo "  序列号: $SERIAL"
    echo "  CPU: ${CPU_CORES}核 $CPU_MODEL"
    echo "  当前温度: ${TEMP}°C"
    
    add_to_report "=== 硬件信息 ==="
    add_to_report "型号: $MODEL"
    add_to_report "版本: Rev $REVISION"
    add_to_report "内存: $((MEMORY / 1024)) MB"
    add_to_report "序列号: $SERIAL"
    add_to_report "CPU: ${CPU_CORES}核 $CPU_MODEL"
    add_to_report "当前温度: ${TEMP}°C"
    
    if [[ "$SERIAL" == "Unknown" ]] || [[ "$MEMORY" == "0" ]]; then
        print_warning "硬件信息读取不完整，请确认设备真伪"
        add_to_report "验机结果: ⚠ 信息不完整，请进一步验证"
    else
        print_success "硬件信息验证完成"
        add_to_report "验机结果: ✓ 基本信息完整"
    fi
    
    check_hardware_compatibility
    check_power_supply
}

# ============================================================================
# 性能优化选项询问
# ============================================================================
ask_performance_optimization() {
    print_step "性能优化选项"
    
    echo -e "${PURPLE}================================================${NC}"
    echo -e "${CYAN}        性能优化选项（支持手动超频）${NC}"
    echo -e "${PURPLE}================================================${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  重要警告：${NC}"
    echo -e "  性能优化（尤其是超频）可能会："
    echo -e "  · 增加功耗和发热量"
    echo -e "  · 在散热不良时影响硬件寿命"
    echo -e "  · 不当设置可能导致系统不稳定"
    echo ""
    echo -e "${GREEN}✅  推荐条件：${NC}"
    echo -e "  · 良好的散热环境（散热片/风扇）"
    echo -e "  · 使用优质电源（至少3A）"
    echo -e "  · 树莓派4B或更新型号"
    echo ""
    
    local enable_perf="n"
    local oc_level=0
    
    if [ "$AUTO_MODE" = true ]; then
        print_info "全自动模式：自动启用性能优化（平衡超频）"
        PERFORMANCE_MODE=true
        OVERCLOCK_LEVEL=2
        MANUAL_ARM_FREQ=1950
        MANUAL_GPU_FREQ=600
        MANUAL_OVER_VOLTAGE=4
        add_to_report "性能优化: 已启用 (全自动平衡超频: ${MANUAL_ARM_FREQ}MHz)"
        log_message "全自动模式：自动启用性能优化，频率: ${MANUAL_ARM_FREQ}MHz"
    else
        read -p "是否启用性能优化（包括超频）？(y/N): " -n 1 enable_perf
        echo ""
        
        if [[ $enable_perf =~ ^[Yy]$ ]]; then
            PERFORMANCE_MODE=true
            
            echo ""
            echo -e "${CYAN}请选择超频方式：${NC}"
            echo "  [1] 保守超频 (1750MHz) - 稳定性优先"
            echo "  [2] 平衡超频 (1950MHz) - 性能与稳定兼顾（默认）"
            echo "  [3] 激进超频 (2100MHz) - 需要优秀散热"
            echo "  [4] 手动自定义 - 自行输入频率/电压"
            echo ""
            read -p "请输入选择 (1-4，默认2): " oc_level
            oc_level=${oc_level:-2}
            
            case $oc_level in
                1)
                    MANUAL_ARM_FREQ=1750
                    MANUAL_GPU_FREQ=550
                    MANUAL_OVER_VOLTAGE=2
                    ;;
                2)
                    MANUAL_ARM_FREQ=1950
                    MANUAL_GPU_FREQ=600
                    MANUAL_OVER_VOLTAGE=4
                    ;;
                3)
                    MANUAL_ARM_FREQ=2100
                    MANUAL_GPU_FREQ=700
                    MANUAL_OVER_VOLTAGE=6
                    ;;
                4)
                    echo ""
                    echo -e "${YELLOW}请输入自定义超频参数（直接回车使用默认值）${NC}"
                    read -p "ARM频率 (MHz) [1950]: " input_arm
                    MANUAL_ARM_FREQ=${input_arm:-1950}
                    read -p "GPU频率 (MHz) [600]: " input_gpu
                    MANUAL_GPU_FREQ=${input_gpu:-600}
                    read -p "over_voltage (2-8) [4]: " input_ov
                    MANUAL_OVER_VOLTAGE=${input_ov:-4}
                    ;;
                *)
                    print_warning "输入无效，使用平衡超频"
                    MANUAL_ARM_FREQ=1950
                    MANUAL_GPU_FREQ=600
                    MANUAL_OVER_VOLTAGE=4
                    ;;
            esac
            
            OVERCLOCK_LEVEL=$oc_level
            print_info "已设置超频参数：ARM=${MANUAL_ARM_FREQ}MHz, GPU=${MANUAL_GPU_FREQ}MHz, over_voltage=${MANUAL_OVER_VOLTAGE}"
            add_to_report "性能优化: 已启用 (手动超频: ARM=${MANUAL_ARM_FREQ} GPU=${MANUAL_GPU_FREQ} over_voltage=${MANUAL_OVER_VOLTAGE})"
            log_message "用户启用性能优化，频率: ${MANUAL_ARM_FREQ}MHz"
        else
            PERFORMANCE_MODE=false
            OVERCLOCK_LEVEL=0
            print_info "跳过性能优化"
            add_to_report "性能优化: 已跳过"
            log_message "用户跳过性能优化"
        fi
    fi
    
    echo "PERFORMANCE_MODE=$PERFORMANCE_MODE" > "$TEMP_DIR/performance.conf"
    echo "OVERCLOCK_LEVEL=$OVERCLOCK_LEVEL" >> "$TEMP_DIR/performance.conf"
    echo "MANUAL_ARM_FREQ=${MANUAL_ARM_FREQ:-0}" >> "$TEMP_DIR/performance.conf"
    echo "MANUAL_GPU_FREQ=${MANUAL_GPU_FREQ:-0}" >> "$TEMP_DIR/performance.conf"
    echo "MANUAL_OVER_VOLTAGE=${MANUAL_OVER_VOLTAGE:-0}" >> "$TEMP_DIR/performance.conf"
}

# ============================================================================
# 系统更新与升级
# ============================================================================
system_update() {
    print_step "系统更新与升级"
    
    if [ "$AUTO_MODE" = false ]; then
        read -p "是否更新系统？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "跳过系统更新"
            add_to_report "系统更新: 跳过"
            return
        fi
    fi
    
    print_info "更新软件包列表..."
    if sudo apt update -y; then
        print_success "软件包列表更新完成"
    else
        print_error "更新失败，请检查网络连接"
        add_to_report "系统更新: ✗ 失败"
        return
    fi
    
    print_info "升级已安装的软件包..."
    if sudo apt full-upgrade -y; then
        print_success "系统升级完成"
        add_to_report "系统更新: ✓ 已完成"
    else
        print_error "升级过程出现错误"
        add_to_report "系统更新: ⚠ 部分完成"
    fi
    
    print_info "清理无用软件包..."
    sudo apt autoremove -y
    sudo apt clean
    print_success "系统清理完成"
}

# ============================================================================
# 存储优化
# ============================================================================
storage_optimization() {
    print_step "存储优化配置"
    
    if [ "$AUTO_MODE" = false ]; then
        read -p "是否扩展文件系统以使用全部SD卡空间？(y/N): " -n 1 -r
        echo
    fi
    
    if [ "$AUTO_MODE" = true ] || [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "扩展文件系统中..."
        if sudo raspi-config nonint do_expand_rootfs 2>/dev/null; then
            print_success "文件系统已扩展（重启后生效）"
            add_to_report "文件系统扩展: ✓ 已配置"
        else
            print_warning "文件系统扩展失败，可能已是最佳状态"
            add_to_report "文件系统扩展: ⚠ 可能无需扩展"
        fi
    else
        add_to_report "文件系统扩展: 跳过"
    fi
    
    if [ "$AUTO_MODE" = false ]; then
        read -p "是否为SD卡启用TRIM支持？(y/N): " -n 1 -r
        echo
    fi
    
    if [ "$AUTO_MODE" = true ] || [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "启用TRIM支持..."
        if command -v fstrim &> /dev/null; then
            sudo fstrim -av 2>/dev/null || true
            sudo systemctl enable fstrim.timer 2>/dev/null && sudo systemctl start fstrim.timer 2>/dev/null
            print_success "TRIM已启用并设置为每周自动运行"
            add_to_report "TRIM支持: ✓ 已启用"
        else
            print_warning "fstrim工具未找到，跳过TRIM配置"
            add_to_report "TRIM支持: ⚠ 未配置"
        fi
    else
        add_to_report "TRIM支持: 跳过"
    fi
}

# ============================================================================
# 内存优化 (ZRAM)
# ============================================================================
memory_optimization() {
    print_step "内存优化配置"
    
    if [ "$AUTO_MODE" = false ]; then
        read -p "是否配置ZRAM交换空间以减少SD卡磨损？(y/N): " -n 1 -r
        echo
    fi
    
    if [ "$AUTO_MODE" = true ] || [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "安装并配置ZRAM..."
        if ! dpkg -l | grep -q zram-tools; then
            sudo apt install -y zram-tools
        fi
        
        if systemctl list-unit-files | grep -q zramswap.service; then
            sudo systemctl enable zramswap.service
            sudo systemctl start zramswap.service
            print_success "ZRAM已配置并启用"
            add_to_report "ZRAM配置: ✓ 已启用"
        else
            print_warning "ZRAM服务未找到或配置失败"
            add_to_report "ZRAM配置: ⚠ 未配置"
        fi
    else
        add_to_report "ZRAM配置: 跳过"
    fi
}

# ============================================================================
# 配置超频函数
# ============================================================================
configure_overclock() {
    if [ -f "$TEMP_DIR/performance.conf" ]; then
        source "$TEMP_DIR/performance.conf"
    else
        print_info "未找到性能配置文件，跳过超频设置"
        return
    fi
    
    if [ "$PERFORMANCE_MODE" != true ] || [ "$OVERCLOCK_LEVEL" -eq 0 ]; then
        print_info "性能优化未启用或级别为0，跳过超频设置"
        add_to_report "超频设置: 未启用"
        return
    fi
    
    print_step "配置超频设置"
    
    if [ -f /boot/config.txt ]; then
        local config_backup="/boot/config_backup_$(date +%Y%m%d_%H%M%S).txt"
        sudo cp /boot/config.txt "$config_backup"
        print_info "已备份原始配置: $config_backup"
    fi
    
    if [ -n "$MANUAL_ARM_FREQ" ] && [ "$MANUAL_ARM_FREQ" -gt 0 ]; then
        print_info "应用手动超频设置：ARM=${MANUAL_ARM_FREQ}MHz, GPU=${MANUAL_GPU_FREQ}MHz, over_voltage=${MANUAL_OVER_VOLTAGE}"
        
        sudo sed -i '/^over_voltage=/d' /boot/config.txt
        sudo sed -i '/^arm_freq=/d' /boot/config.txt
        sudo sed -i '/^gpu_freq=/d' /boot/config.txt
        sudo sed -i '/^force_turbo=/d' /boot/config.txt
        sudo sed -i '/^# 手动超频设置 (v3.6.0脚本)/d' /boot/config.txt
        
        sudo tee -a /boot/config.txt > /dev/null << EOF

# 手动超频设置 (v3.6.0脚本)
over_voltage=${MANUAL_OVER_VOLTAGE}
arm_freq=${MANUAL_ARM_FREQ}
gpu_freq=${MANUAL_GPU_FREQ}
EOF
        
        if [ "$OVERCLOCK_LEVEL" = 3 ]; then
            echo "force_turbo=1" | sudo tee -a /boot/config.txt > /dev/null
            print_warning "已启用 force_turbo 模式"
        fi
        
        print_success "超频设置已应用 (ARM=${MANUAL_ARM_FREQ}MHz)"
        add_to_report "超频设置: ✓ 已应用 (手动: ARM=${MANUAL_ARM_FREQ} GPU=${MANUAL_GPU_FREQ} over_voltage=${MANUAL_OVER_VOLTAGE})"
        log_message "超频设置应用成功，频率: ${MANUAL_ARM_FREQ}MHz"
    else
        print_error "超频参数无效，跳过设置"
        add_to_report "超频设置: ✗ 参数无效"
        return
    fi
    
    if [ "$UNDERVOLT_DETECTED" = true ]; then
        echo -e "\n${RED}════════════════════════════════════════${NC}"
        print_error "检测到电源欠压！超频可能不稳定！"
        print_error "强烈建议使用优质电源（至少3A）"
        echo -e "${RED}════════════════════════════════════════${NC}"
    fi
}

# ============================================================================
# 智能中文支持安装
# ============================================================================
chinese_support() {
    print_step "中文环境支持"
    
    if [ ! -f /tmp/network_env ]; then
        detect_network_environment
    fi
    source /tmp/network_env
    
    if [ "$AUTO_MODE" = true ]; then
        if [ "$IS_IN_CHINA" = true ]; then
            print_info "全自动模式：检测到中国用户，安装中文支持"
            SKIP_CHINESE=false
        else
            print_info "Auto Mode: International user detected, skipping Chinese support"
            SKIP_CHINESE=true
            add_to_report "中文支持: 跳过（非中国用户）"
            return
        fi
    else
        read -p "是否安装中文语言包、字体和输入法？(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "跳过中文支持安装"
            add_to_report "中文支持: 跳过"
            SKIP_CHINESE=true
            return
        fi
        SKIP_CHINESE=false
    fi
    
    print_info "安装中文语言包..."
    sudo apt install -y language-pack-zh-hans language-pack-zh-hant || print_warning "中文语言包安装失败"
    
    print_info "安装中文字体..."
    sudo apt install -y fonts-wqy-zenhei fonts-wqy-microhei || print_warning "中文字体安装失败"
    
    print_info "安装中文输入法..."
    sudo apt install -y ibus ibus-libpinyin ibus-clutter || print_warning "中文输入法安装失败"
    
    print_info "配置中文区域设置..."
    sudo sed -i '/zh_CN.UTF-8/s/^# //g' /etc/locale.gen 2>/dev/null || true
    sudo locale-gen zh_CN.UTF-8 2>/dev/null || true
    sudo update-locale LANG=zh_CN.UTF-8 LC_MESSAGES=zh_CN.UTF-8 2>/dev/null || true
    
    local user_home=$(eval echo ~$ACTUAL_USER)
    if [ -d "/usr/share/raspi-ui-overrides" ] || [ -d "/etc/xdg/autostart" ]; then
        mkdir -p "$user_home/.config/autostart" 2>/dev/null
        cat > "$user_home/.config/autostart/ibus.desktop" << EOF
[Desktop Entry]
Type=Application
Name=IBus Input Method
Exec=ibus-daemon -drx
Comment=Chinese Input Method
X-GNOME-Autostart-enabled=true
EOF
        
        echo "" >> "$user_home/.bashrc"
        echo "# 中文输入法设置" >> "$user_home/.bashrc"
        echo "export GTK_IM_MODULE=ibus" >> "$user_home/.bashrc"
        echo "export XMODIFIERS=@im=ibus" >> "$user_home/.bashrc"
        echo "export QT_IM_MODULE=ibus" >> "$user_home/.bashrc"
        
        chown -R $ACTUAL_USER:$ACTUAL_USER "$user_home/.config" 2>/dev/null || true
        chown $ACTUAL_USER:$ACTUAL_USER "$user_home/.bashrc" 2>/dev/null || true
    fi
    
    print_success "中文环境支持安装完成！重启后生效。"
    print_info "提示：重启后可按 Ctrl+Space 切换中英文输入法"
    add_to_report "中文支持: ✓ 已安装"
}

# ============================================================================
# 添加温度监控功能
# ============================================================================
add_temperature_monitoring() {
    print_step "添加温度监控功能"
    
    local user_home=$(eval echo ~$ACTUAL_USER)
    local monitor_script="$user_home/temp_monitor.sh"
    local service_file="/etc/systemd/system/temp-monitor.service"
    
    cat > "$monitor_script" << 'EOF'
#!/bin/bash
USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
LOG_FILE="$USER_HOME/temp_monitor.log"
MAX_TEMP=75
CRITICAL_TEMP=80
CHECK_INTERVAL=10

mkdir -p "$(dirname "$LOG_FILE")"
echo "温度监控启动于 $(date)" >> "$LOG_FILE"

while true; do
    temp="N/A"
    if command -v vcgencmd > /dev/null; then
        temp_output=$(vcgencmd measure_temp 2>/dev/null)
        if [ $? -eq 0 ]; then
            temp=$(echo "$temp_output" | cut -d= -f2 | cut -d\' -f1)
        fi
    fi
    
    if [ "$temp" = "N/A" ]; then
        if [ -f "/sys/class/thermal/thermal_zone0/temp" ]; then
            temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
            if [ -n "$temp_raw" ]; then
                temp=$(echo "scale=1; $temp_raw / 1000" | bc 2>/dev/null || echo "N/A")
            fi
        fi
    fi
    
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    if [ "$temp" != "N/A" ]; then
        temp_compare=$(echo "$temp" | awk '{printf "%.1f", $1}')
        
        if (( $(echo "$temp_compare >= $CRITICAL_TEMP" | bc -l 2>/dev/null) )); then
            echo "CRITICAL: $timestamp - 温度过高！当前温度: ${temp}°C" >> "$LOG_FILE"
            if command -v wall > /dev/null; then
                echo "CRITICAL: $timestamp - CPU温度过高！当前: ${temp}°C" | wall 2>/dev/null || true
            fi
        elif (( $(echo "$temp_compare >= $MAX_TEMP" | bc -l 2>/dev/null) )); then
            echo "WARNING: $timestamp - 温度较高！当前温度: ${temp}°C" >> "$LOG_FILE"
        fi
        
        if [ $(date +%S) -lt 10 ]; then
            echo "INFO: $timestamp - 当前温度: ${temp}°C" >> "$LOG_FILE"
        fi
    fi
    
    sleep $CHECK_INTERVAL
done
EOF
    
    chmod +x "$monitor_script"
    chown $ACTUAL_USER:$ACTUAL_USER "$monitor_script"
    print_success "温度监控脚本已创建: $monitor_script"
    
    if [ "$AUTO_MODE" = true ]; then
        print_info "全自动模式：自动创建温度监控服务"
        
        sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=Raspberry Pi Temperature Monitor
After=multi-user.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash $monitor_script
WorkingDirectory=$user_home
Restart=always
RestartSec=10
User=$ACTUAL_USER
Group=$ACTUAL_USER
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
        
        sudo systemctl daemon-reload
        sudo systemctl enable temp-monitor.service 2>/dev/null
        sudo systemctl start temp-monitor.service
        sleep 2
        
        if systemctl is-active temp-monitor.service >/dev/null 2>&1; then
            print_success "温度监控服务已启用并启动"
            add_to_report "温度监控: ✓ 已启用 (systemd服务)"
        else
            print_warning "温度监控服务启动失败，请手动运行: $monitor_script"
            add_to_report "温度监控: ⚠ 脚本已创建，服务启动失败"
        fi
    else
        read -p "是否创建自动启动的温度监控服务？(y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=Raspberry Pi Temperature Monitor
After=multi-user.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash $monitor_script
WorkingDirectory=$user_home
Restart=always
RestartSec=10
User=$ACTUAL_USER
Group=$ACTUAL_USER
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
            
            sudo systemctl daemon-reload
            sudo systemctl enable temp-monitor.service 2>/dev/null
            sudo systemctl start temp-monitor.service
            sleep 2
            
            if systemctl is-active temp-monitor.service >/dev/null 2>&1; then
                print_success "温度监控服务已启用并启动"
                add_to_report "温度监控: ✓ 已启用 (systemd服务)"
            else
                print_warning "温度监控服务启动失败，请手动运行: $monitor_script"
                add_to_report "温度监控: ⚠ 脚本已创建，服务启动失败"
            fi
        else
            print_info "温度监控脚本已创建，可手动运行: $monitor_script"
            add_to_report "温度监控: ✓ 脚本已创建"
        fi
    fi
    
    echo -e "\n# 温度监控别名" >> "$user_home/.bashrc"
    echo "alias temp='vcgencmd measure_temp 2>/dev/null || cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk \"{printf \\\"温度: %.1f°C\\\", \\\$1/1000}\"'" >> "$user_home/.bashrc"
    echo "alias temp-log='tail -20 $user_home/temp_monitor.log 2>/dev/null || echo \"日志文件不存在\"'" >> "$user_home/.bashrc"
    echo "alias temp-monitor='sudo systemctl status temp-monitor.service 2>/dev/null || echo \"温度监控服务未运行\"'" >> "$user_home/.bashrc"
    
    chown $ACTUAL_USER:$ACTUAL_USER "$user_home/.bashrc" 2>/dev/null || true
    
    print_info "已添加快捷命令："
    echo "  temp          - 查看当前温度"
    echo "  temp-log      - 查看温度日志"
    echo "  temp-monitor  - 查看监控服务状态"
}

# ============================================================================
# 性能测试
# ============================================================================
performance_test() {
    print_step "性能测试"
    
    if [ "$AUTO_MODE" = false ]; then
        read -p "是否运行快速性能测试？（约1分钟）(y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "跳过性能测试"
            add_to_report "性能测试: 跳过"
            return
        fi
    fi
    
    print_info "运行CPU压力测试（10秒）..."
    timeout 10s yes > /dev/null 2>&1
    print_success "CPU压力测试完成"
    
    local mem_speed="N/A"
    if command -v sysbench &> /dev/null; then
        print_info "测试内存速度..."
        mem_speed=$(sysbench memory run 2>/dev/null | grep "transferred" | grep -o '[0-9.]\+ MiB/sec' | head -1)
        echo "  内存速度: ${mem_speed:-"测试失败"}"
    else
        print_warning "sysbench未安装，跳过内存速度测试"
    fi
    
    print_info "测试SD卡写入速度..."
    local test_file="/tmp/test_$(date +%s).bin"
    local disk_speed_output=$(dd if=/dev/zero of="$test_file" bs=1M count=50 oflag=direct 2>&1)
    rm -f "$test_file"
    local disk_speed=$(echo "$disk_speed_output" | tail -1 | grep -o '[0-9.]\+ [GM]B/s')
    echo "  磁盘速度: ${disk_speed:-"测试失败"}"
    
    print_info "获取实时系统状态："
    local temp="N/A"
    local volts="N/A"
    local clock="N/A"
    if command -v vcgencmd &> /dev/null; then
        temp=$(vcgencmd measure_temp)
        volts=$(vcgencmd measure_volts)
        clock=$(vcgencmd measure_clock arm | awk -F= '{printf "%.0f MHz", $2/1000000}')
    fi
    echo "  温度: $temp"
    echo "  电压: $volts"
    echo "  CPU频率: $clock"
    
    if [ "$PERFORMANCE_MODE" = true ] && [ "$OVERCLOCK_LEVEL" -gt 0 ]; then
        echo -e "\n${CYAN}超频状态检查：${NC}"
        
        local actual_clock=$(vcgencmd measure_clock arm 2>/dev/null | awk -F= '{printf "%.0f", $2/1000000}')
        local target_clock=0
        
        case $OVERCLOCK_LEVEL in
            1) target_clock=1750 ;;
            2) target_clock=1950 ;;
            3) target_clock=2100 ;;
        esac
        
        if [ $target_clock -gt 0 ] && [ $actual_clock -ge $((target_clock - 100)) ]; then
            print_success "CPU频率已达到目标: ${actual_clock}MHz"
        else
            print_warning "CPU频率未达目标: ${actual_clock:-"N/A"}MHz (目标: ${target_clock}MHz)"
            print_info "可能需要重启或检查散热"
        fi
    fi
    
    add_to_report "=== 性能测试 ==="
    add_to_report "CPU测试: 完成"
    add_to_report "内存速度: ${mem_speed:-"N/A"}"
    add_to_report "磁盘速度: ${disk_speed:-"N/A"}"
    add_to_report "系统状态: $temp, $volts, $clock"
    
    print_success "性能测试完成"
}

# ============================================================================
# 恢复默认设置功能
# ============================================================================
restore_backups() {
    print_step "恢复默认设置选项"
    
    echo -e "${YELLOW}此功能将恢复所有备份的配置文件：${NC}"
    echo "  1) 恢复软件源配置"
    echo "  2) 恢复超频设置（仅删除超频相关行）"
    echo "  3) 恢复所有配置"
    echo "  4) 查看备份文件"
    echo "  5) 取消"
    
    read -p "请选择 (1-5): " -n 1 restore_choice
    echo
    
    case $restore_choice in
        1)
            if ls /etc/apt/sources.list.backup.* >/dev/null 2>&1; then
                local latest_backup=$(ls -t /etc/apt/sources.list.backup.* | head -1)
                sudo cp "$latest_backup" /etc/apt/sources.list
                print_success "软件源已恢复"
            else
                print_warning "未找到软件源备份"
            fi
            ;;
        2)
            if [ -f /boot/config.txt ]; then
                sudo sed -i '/^# 手动超频设置 (v3.6.0脚本)/d' /boot/config.txt
                sudo sed -i '/^over_voltage=/d' /boot/config.txt
                sudo sed -i '/^arm_freq=/d' /boot/config.txt
                sudo sed -i '/^gpu_freq=/d' /boot/config.txt
                sudo sed -i '/^force_turbo=/d' /boot/config.txt
                print_success "超频设置已删除，系统将使用默认频率"
                print_warning "重启后生效"
            else
                print_warning "/boot/config.txt 不存在"
            fi
            ;;
        3)
            if ls /etc/apt/sources.list.backup.* >/dev/null 2>&1; then
                local latest_sources=$(ls -t /etc/apt/sources.list.backup.* | head -1)
                sudo cp "$latest_sources" /etc/apt/sources.list
                print_success "软件源已恢复"
            fi
            
            if [ -f /boot/config.txt ]; then
                sudo sed -i '/^# 手动超频设置 (v3.6.0脚本)/d' /boot/config.txt
                sudo sed -i '/^over_voltage=/d' /boot/config.txt
                sudo sed -i '/^arm_freq=/d' /boot/config.txt
                sudo sed -i '/^gpu_freq=/d' /boot/config.txt
                sudo sed -i '/^force_turbo=/d' /boot/config.txt
                print_success "超频设置已恢复"
            fi
            
            print_info "所有配置已恢复，建议重启系统"
            ;;
        4)
            echo -e "\n${CYAN}备份文件列表：${NC}"
            echo "软件源备份:"
            ls -la /etc/apt/sources.list.backup.* 2>/dev/null || echo "  无备份"
            echo -e "\n超频配置备份:"
            ls -la /boot/config_backup_*.txt 2>/dev/null || echo "  无备份"
            ;;
        5|*)
            print_info "取消恢复操作"
            return
            ;;
    esac
    
    add_to_report "恢复操作: 执行了选项 $restore_choice"
}

# ============================================================================
# 生成报告
# ============================================================================
generate_report() {
    print_step "生成优化报告"
    
    local report_file="$HOME/pi_optimization_report_$(date +%Y%m%d_%H%M%S).txt"
    local report_content="树莓派优化与验机报告\n生成时间: $(date)\n脚本版本: v3.6.0\n脚本模式: $([ "$AUTO_MODE" = true ] && echo "全自动模式" || echo "交互模式")\n"
    report_content+="========================================\n"
    report_content+="$REPORT_DATA"
    
    report_content+="\n=== 总结与建议 ===\n"
    report_content+="1. 部分优化需要重启才能完全生效。\n"
    if [ "$SKIP_CHINESE" = false ] && [ "$IS_IN_CHINA" = true ]; then
        report_content+="2. 中文支持已安装，重启后生效。\n"
    fi
    if [ "$PERFORMANCE_MODE" = true ] && [ "$OVERCLOCK_LEVEL" -gt 0 ]; then
        report_content+="3. 超频设置已应用（级别 $OVERCLOCK_LEVEL），重启后生效。\n"
        report_content+="4. 超频后请密切监控系统温度，确保散热良好。\n"
    fi
    if [ "$UNDERVOLT_DETECTED" = true ]; then
        report_content+="5. ⚠️ 检测到电源欠压，建议更换优质电源！\n"
    fi
    report_content+="6. 建议定期检查系统更新：sudo apt update && sudo apt upgrade\n"
    report_content+="7. 监控温度命令：temp 或 vcgencmd measure_temp\n"
    report_content+="8. 查看温度日志：temp-log\n"
    
    printf "%b\n" "$report_content" > "$report_file"
    
    if [ -f "$report_file" ]; then
        print_success "报告已生成: $report_file"
        echo -e "${YELLOW}========================================${NC}"
        echo -e "${CYAN}重要提醒：${NC}"
        echo "1. 部分优化需要重启才能生效。"
        echo "2. 中文环境重启后生效，按 Ctrl+Space 切换输入法。"
        if [ "$PERFORMANCE_MODE" = true ] && [ "$OVERCLOCK_LEVEL" -gt 0 ]; then
            echo "3. 超频设置需要重启生效，请确保散热良好。"
        fi
        if [ "$UNDERVOLT_DETECTED" = true ]; then
            echo "4. ${RED}检测到电源欠压！建议更换优质电源！${NC}"
        fi
        echo "5. 查看完整报告：cat $report_file"
        echo "6. 快速温度检查：temp"
        echo -e "${YELLOW}========================================${NC}"
        
        echo -e "\n${GREEN}报告摘要：${NC}"
        head -n 30 "$report_file"
    else
        print_error "报告生成失败"
    fi
}

# ============================================================================
# 重启选项
# ============================================================================
reboot_option() {
    echo -e "\n${YELLOW}========================================${NC}"
    
    if [ "$AUTO_MODE" = false ]; then
        read -p "是否先查看/恢复备份设置？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            restore_backups
        fi
    fi
    
    echo -e "${YELLOW}========================================${NC}"
    
    if [ "$AUTO_MODE" = true ]; then
        print_info "全自动模式执行完成！"
        print_warning "系统将在30秒后自动重启，以使所有优化生效。"
        print_warning "如需取消，请立即按 ${RED}Ctrl+C${NC} 键中断。"
        echo -e "${YELLOW}========================================${NC}"
        
        for i in {30..1}; do
            echo -ne "  \r${i}秒后自动重启..."
            sleep 1
        done
        
        echo -e "\n${GREEN}正在重启系统...${NC}"
        add_to_report "系统操作：已执行自动重启"
        sudo reboot
    else
        print_info "部分优化（如文件系统扩展、中文支持、超频设置）需要重启才能完全生效。"
        
        echo -e "\n${CYAN}重启选项：${NC}"
        echo "  1) 立即重启"
        echo "  2) 延迟10分钟重启"
        echo "  3) 延迟30分钟重启"
        echo "  4) 不重启，稍后手动重启"
        echo "  5) 查看重启后需检查的事项"
        
        read -p "请选择 (1-5): " -n 1 -r
        echo
        
        case $REPLY in
            1)
                print_info "系统将在10秒后重启，按 Ctrl+C 取消..."
                for i in {10..1}; do
                    echo -ne "  \r${i}秒后重启..."
                    sleep 1
                done
                echo -e "\n正在重启系统..."
                sudo reboot
                ;;
            2)
                if command -v at &> /dev/null; then
                    print_info "系统将在10分钟后重启..."
                    echo "sudo shutdown -r +10" | at now +10 minutes
                    print_info "已安排延迟重启，可使用 'atq' 查看，'atrm <作业号>' 取消"
                else
                    print_warning "at 命令未安装，无法安排延迟重启"
                    print_info "请手动执行：sudo shutdown -r +10 或 sudo reboot"
                fi
                ;;
            3)
                if command -v at &> /dev/null; then
                    print_info "系统将在30分钟后重启..."
                    echo "sudo shutdown -r +30" | at now +30 minutes
                    print_info "已安排延迟重启，可使用 'atq' 查看，'atrm <作业号>' 取消"
                else
                    print_warning "at 命令未安装，无法安排延迟重启"
                    print_info "请手动执行：sudo shutdown -r +30 或 sudo reboot"
                fi
                ;;
            4)
                print_info "您可以选择稍后手动重启：${GREEN}sudo reboot${NC}"
                ;;
            5)
                echo -e "\n${CYAN}重启后建议检查：${NC}"
                echo "1. 检查温度：temp 或 vcgencmd measure_temp"
                echo "2. 检查频率：vcgencmd measure_clock arm"
                echo "3. 检查电源状态：vcgencmd get_throttled"
                echo "4. 检查中文输入法：按 Ctrl+Space 切换"
                echo "5. 检查服务状态：systemctl status temp-monitor.service"
                echo "6. 查看系统日志：dmesg | tail -20"
                echo "7. 检查超频状态：grep -E 'over_voltage|arm_freq|gpu_freq' /boot/config.txt"
                echo -e "\n按 Enter 返回重启选项..."
                read
                reboot_option
                ;;
            *)
                print_info "您可以选择稍后手动重启：${GREEN}sudo reboot${NC}"
                ;;
        esac
    fi
}

# ============================================================================
# 清理函数
# ============================================================================
cleanup() {
    echo -e "\n${CYAN}正在清理临时文件...${NC}"
    rm -rf "$TEMP_DIR" 2>/dev/null || true
    print_success "清理完成"
}

# ============================================================================
# 主程序
# ============================================================================
main() {
    init_environment
    
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}请使用sudo运行此脚本：${NC}"
        echo -e "${YELLOW}sudo bash $(basename "$0")${NC}"
        log_message "错误：未使用sudo运行"
        exit 1
    fi
    
    print_header
    ask_performance_optimization
    
    detect_hardware
    configure_sources
    system_update
    storage_optimization
    memory_optimization
    configure_overclock
    chinese_support
    add_temperature_monitoring
    performance_test
    generate_report
    reboot_option
    
    cleanup
    echo -e "\n${GREEN}脚本执行完成！感谢使用树莓派优化脚本 v3.6.0！${NC}"
    echo -e "${CYAN}如有问题，请查看日志文件：$LOG_FILE${NC}"
}

trap cleanup EXIT
main