#!/bin/bash
# ============================================================================
# 树莓派智能优化脚本 v3.5.1
# 作者：小何-winp电脑（XiaoHe_winpc）
# 功能：硬件验机 + 系统优化 + 中文支持 + 性能测试 + 智能超频 + 温度监控
# 特点：1. 全自动模式（输入A） | 2. 交互模式
#       3. 全自动模式下智能判断是否安装中文支持
#       4. 新增智能超频与综合性能优化选项
#       5. 新增硬件兼容性检查与温度监控
# 使用方法：sudo bash v3.5.1.sh
# ============================================================================

# 颜色定义
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
PURPLE='\033[1;35m'
NC='\033[0m' # No Color

# 全局变量
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

# 初始化环境
init_environment() {
    mkdir -p "$TEMP_DIR"
    exec 2> >(tee -a "$LOG_FILE")
    log_message "脚本启动 - 树莓派优化脚本 v3.5.1"
}

# 记录日志
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

print_header() {
    clear
    echo -e "${CYAN}"
    echo "================================================"
    echo "      树莓派智能优化与验机脚本 v3.5.1"
    echo "================================================"
    echo -e "${NC}"
    echo -e "${PURPLE}新增特性：智能超频 + 综合性能优化 + 温度监控${NC}"
    echo ""
    echo "模式选择："
    echo "  1. 全自动模式 - 输入 ${GREEN}A${NC}（推荐新手）"
    echo "  2. 交互模式   - 直接按 ${GREEN}Enter${NC}（高级用户）"
    echo "================================================"
    echo ""
    read -p "请选择运行模式: " -n 1 USER_CHOICE
    echo ""
    
    if [[ "$USER_CHOICE" == "A" || "$USER_CHOICE" == "a" ]]; then
        AUTO_MODE=true
        echo -e "${GREEN}已启用全自动模式！${NC}"
        log_message "启用全自动模式"
        echo -e "${YELLOW}注意：全自动模式将自动执行基础优化。${NC}"
        echo -e "${YELLOW}      性能优化选项将在下一步询问。${NC}"
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
    REPORT_DATA+="${1}\n"
}

# ============================================================================
# 【v3.5 新增】硬件兼容性检查
# ============================================================================
check_hardware_compatibility() {
    print_step "检查硬件兼容性"
    
    # 获取树莓派型号
    RASPI_MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "Unknown")
    RASPI_REVISION=$(cat /proc/device-tree/model | rev | cut -d ' ' -f 1 | rev 2>/dev/null || echo "Unknown")
    
    echo "  检测到型号: $RASPI_MODEL"
    echo "  硬件版本: Rev $RASPI_REVISION"
    
    # 检查是否支持超频
    if [[ "$RASPI_MODEL" == *"Raspberry Pi Zero"* ]]; then
        print_warning "树莓派 Zero 型号性能有限，不建议超频"
        if [ "$OVERCLOCK_LEVEL" -gt 1 ]; then
            print_warning "Zero 型号不支持高级超频，已自动调整为级别1"
            OVERCLOCK_LEVEL=1
        fi
    elif [[ "$RASPI_MODEL" == *"Raspberry Pi 1"* ]] || [[ "$RASPI_MODEL" == *"Model A"* ]] || [[ "$RASPI_MODEL" == *"Model B"* ]]; then
        print_warning "旧款树莓派（1代）超频能力有限，建议谨慎操作"
        if [ "$OVERCLOCK_LEVEL" -gt 2 ]; then
            print_warning "一代型号不支持激进超频，已自动调整为级别2"
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
    
    # 保存型号信息
    echo "RASPI_MODEL='$RASPI_MODEL'" > "$TEMP_DIR/raspi_info"
    echo "RASPI_REVISION='$RASPI_REVISION'" >> "$TEMP_DIR/raspi_info"
    
    add_to_report "=== 硬件兼容性检查 ==="
    add_to_report "型号: $RASPI_MODEL"
    add_to_report "版本: Rev $RASPI_REVISION"
}

# ============================================================================
# 【v3.5 新增】电源检测函数
# ============================================================================
check_power_supply() {
    print_step "检测电源状态"
    
    # 检查是否有vcgencmd命令
    if ! command -v vcgencmd &> /dev/null; then
        print_warning "vcgencmd 命令未找到，跳过电源检测"
        add_to_report "电源检测: ⚠ 工具未安装"
        return 1
    fi
    
    # 获取电源状态
    local throttled=$(vcgencmd get_throttled)
    local undervolt=$(vcgencmd get_throttled | cut -d'=' -f2)
    
    echo "  电源状态: $throttled"
    
    # 检查各种状态标志位
    if [ $((undervolt & 0x1)) -eq 1 ]; then
        print_error "检测到电源欠压！"
        print_error "请使用优质电源（至少3A）并确保连接良好"
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
    
    # 如果检测到欠压，询问是否继续
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
# 【v3.0 新增】性能优化选项询问（支持手动超频）
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
    
    # 全自动模式
    if [ "$AUTO_MODE" = true ]; then
        print_info "全自动模式：自动启用性能优化（平衡超频）"
        PERFORMANCE_MODE=true
        OVERCLOCK_LEVEL=2
        # 全自动模式使用平衡超频参数
        MANUAL_ARM_FREQ=1950
        MANUAL_GPU_FREQ=600
        MANUAL_OVER_VOLTAGE=4
        add_to_report "性能优化: 已启用 (全自动平衡超频: ${MANUAL_ARM_FREQ}MHz)"
        log_message "全自动模式：自动启用性能优化，频率: ${MANUAL_ARM_FREQ}MHz"
    else
        # 交互模式
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
    
    # 保存性能配置（包含手动参数）
    echo "PERFORMANCE_MODE=$PERFORMANCE_MODE" > "$TEMP_DIR/performance.conf"
    echo "OVERCLOCK_LEVEL=$OVERCLOCK_LEVEL" >> "$TEMP_DIR/performance.conf"
    echo "MANUAL_ARM_FREQ=${MANUAL_ARM_FREQ:-0}" >> "$TEMP_DIR/performance.conf"
    echo "MANUAL_GPU_FREQ=${MANUAL_GPU_FREQ:-0}" >> "$TEMP_DIR/performance.conf"
    echo "MANUAL_OVER_VOLTAGE=${MANUAL_OVER_VOLTAGE:-0}" >> "$TEMP_DIR/performance.conf"
}

# ============================================================================
# 智能中文支持安装（全自动模式下智能判断）
# ============================================================================
chinese_support() {
    print_step "中文环境支持"
    
    # 如果是全自动模式，根据网络环境智能决定
    if [ "$AUTO_MODE" = true ]; then
        if [ "$IS_IN_CHINA" = true ]; then
            print_info "全自动模式：检测到中国用户，安装中文支持"
            SKIP_CHINESE=false
        else
            print_info "Auto Mode: International user detected, skipping Chinese support"
            print_info "（非中国用户通常不需要中文支持）"
            SKIP_CHINESE=true
            add_to_report "中文支持: 跳过（非中国用户）"
            return
        fi
    else
        # 交互模式下询问用户
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
    
    # 安装中文支持
    print_info "安装中文语言包..."
    if sudo apt install -y language-pack-zh-hans language-pack-zh-hant 2>/dev/null; then
        print_success "中文语言包安装完成"
    else
        print_warning "中文语言包安装失败，继续其他安装"
    fi
    
    print_info "安装中文字体..."
    if sudo apt install -y fonts-wqy-zenhei fonts-wqy-microhei 2>/dev/null; then
        print_success "中文字体安装完成"
    else
        print_warning "中文字体安装失败"
    fi
    
    print_info "安装中文输入法..."
    if sudo apt install -y ibus ibus-libpinyin ibus-clutter 2>/dev/null; then
        print_success "中文输入法安装完成"
    else
        print_warning "中文输入法安装失败"
    fi
    
    print_info "配置中文区域设置..."
    sudo sed -i '/zh_CN.UTF-8/s/^# //g' /etc/locale.gen 2>/dev/null || true
    sudo locale-gen zh_CN.UTF-8 2>/dev/null || true
    sudo update-locale LANG=zh_CN.UTF-8 LC_MESSAGES=zh_CN.UTF-8 2>/dev/null || true
    
    # 配置输入法自动启动（仅限桌面环境）
    if [ -d "/usr/share/raspi-ui-overrides" ] || [ -d "/etc/xdg/autostart" ]; then
        local user_home="$HOME"
        if [ "$EUID" -eq 0 ]; then
            user_home="/home/pi"
        fi
        
        mkdir -p "$user_home/.config/autostart" 2>/dev/null
        cat > "$user_home/.config/autostart/ibus.desktop" << EOF
[Desktop Entry]
Type=Application
Name=IBus Input Method
Exec=ibus-daemon -drx
Comment=Chinese Input Method
X-GNOME-Autostart-enabled=true
EOF
        
        # 设置环境变量
        echo "export GTK_IM_MODULE=ibus" >> "$user_home/.bashrc"
        echo "export XMODIFIERS=@im=ibus" >> "$user_home/.bashrc"
        echo "export QT_IM_MODULE=ibus" >> "$user_home/.bashrc"
    fi
    
    print_success "中文环境支持安装完成！重启后生效。"
    print_info "提示：重启后可按 Ctrl+Space 切换中英文输入法"
    add_to_report "中文支持: ✓ 已安装"
}

# ============================================================================
# 配置软件源（智能选择）
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
    print_info "备份原始源文件中..."
    local backup_time=$(date +%Y%m%d_%H%M%S)
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.backup.$backup_time 2>/dev/null
    sudo cp /etc/apt/sources.list.d/raspi.list /etc/apt/sources.list.d/raspi.list.backup.$backup_time 2>/dev/null
    
    if [ "$IS_IN_CHINA" = true ]; then
        # 配置清华大学镜像源
        print_info "设置清华大学镜像源..."
        
        # 更新 Debian 源
        sudo sed -i 's|deb.debian.org/debian|mirrors.tuna.tsinghua.edu.cn/debian|g' /etc/apt/sources.list
        sudo sed -i 's|security.debian.org/debian-security|mirrors.tuna.tsinghua.edu.cn/debian-security|g' /etc/apt/sources.list
        
        # 更新 Raspberry Pi 源
        if [ -f /etc/apt/sources.list.d/raspi.list ]; then
            sudo sed -i 's|archive.raspberrypi.org/debian|mirrors.tuna.tsinghua.edu.cn/raspberrypi|g' /etc/apt/sources.list.d/raspi.list
        fi
        
        add_to_report "软件源: 清华大学镜像"
        print_success "已配置国内镜像源，下载速度更快"
    else
        print_info "Using default Raspberry Pi OS sources"
        add_to_report "软件源: 默认官方源"
    fi
    
    print_success "软件源配置完成"
}

# ============================================================================
# 硬件信息检测
# ============================================================================
detect_hardware() {
    print_step "硬件信息检测"
    
    # 获取模型信息
    local MODEL=$(tr -d '\0' < /proc/device-tree/model 2>/dev/null || echo "Unknown")
    local SERIAL=$(cat /proc/cpuinfo | grep Serial | cut -d ' ' -f 2 2>/dev/null || echo "Unknown")
    local MEMORY=$(vcgencmd get_config total_mem | cut -d '=' -f 2 2>/dev/null || echo "0")
    local REVISION=$(cat /proc/device-tree/model | rev | cut -d ' ' -f 1 | rev 2>/dev/null || echo "Unknown")
    
    # 获取CPU信息
    local CPU_MODEL=$(cat /proc/cpuinfo | grep "model name" | head -1 | cut -d ':' -f 2 | sed 's/^[ \t]*//')
    local CPU_CORES=$(nproc)
    
    # 获取温度
    local TEMP=$(vcgencmd measure_temp | cut -d '=' -f 2 | cut -d "'" -f 1 2>/dev/null || echo "0")
    
    # 显示信息
    echo "  主板型号: $MODEL"
    echo "  硬件版本: Rev $REVISION"
    echo "  内存总量: $((MEMORY / 1024)) MB"
    echo "  序列号: $SERIAL"
    echo "  CPU: ${CPU_CORES}核 $CPU_MODEL"
    echo "  当前温度: ${TEMP}°C"
    
    # 添加到报告
    add_to_report "=== 硬件信息 ==="
    add_to_report "型号: $MODEL"
    add_to_report "版本: Rev $REVISION"
    add_to_report "内存: $((MEMORY / 1024)) MB"
    add_to_report "序列号: $SERIAL"
    add_to_report "CPU: ${CPU_CORES}核 $CPU_MODEL"
    add_to_report "当前温度: ${TEMP}°C"
    
    # 验证树莓派真伪（简单验证）
    if [[ "$SERIAL" == "Unknown" ]] || [[ "$MEMORY" == "0" ]]; then
        print_warning "硬件信息读取不完整，请确认设备真伪"
        add_to_report "验机结果: ⚠ 信息不完整，请进一步验证"
    else
        print_success "硬件信息验证完成"
        add_to_report "验机结果: ✓ 基本信息完整"
    fi
    
    # 检查硬件兼容性
    check_hardware_compatibility
    
    # 检查电源状态
    check_power_supply
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
    
    # 扩展文件系统
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
    
    # 启用TRIM
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
            sudo apt install -y zram-tools 2>/dev/null
        fi
        
        if systemctl is-enabled zram-config >/dev/null 2>&1; then
            sudo systemctl enable zram-config
            sudo systemctl start zram-config
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
# 【v3.0 新增】配置超频函数（完全手动模式）
# ============================================================================
configure_overclock() {
    # 读取性能配置
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
    
    # 备份原始配置文件
    local config_backup="/boot/config_backup_$(date +%Y%m%d_%H%M%S).txt"
    sudo cp /boot/config.txt "$config_backup" 2>/dev/null
    print_info "已备份原始配置: $config_backup"
    
    # 直接使用手动设置的参数（不再根据型号自动适配）
    if [ -n "$MANUAL_ARM_FREQ" ] && [ "$MANUAL_ARM_FREQ" -gt 0 ]; then
        print_info "应用手动超频设置：ARM=${MANUAL_ARM_FREQ}MHz, GPU=${MANUAL_GPU_FREQ}MHz, over_voltage=${MANUAL_OVER_VOLTAGE}"
        
        sudo tee -a /boot/config.txt > /dev/null << EOF

# 手动超频设置 (v3.6脚本)
over_voltage=${MANUAL_OVER_VOLTAGE}
arm_freq=${MANUAL_ARM_FREQ}
gpu_freq=${MANUAL_GPU_FREQ}
EOF
        
        # 只有激进超频才启用 force_turbo
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
    
    # 如果检测到欠压，特别提醒
    if [ "$UNDERVOLT_DETECTED" = true ]; then
        echo -e "\n${RED}════════════════════════════════════════${NC}"
        print_error "检测到电源欠压！超频可能不稳定！"
        print_error "强烈建议使用优质电源（至少3A）"
        echo -e "${RED}════════════════════════════════════════${NC}"
    fi
}

# ============================================================================
# 【v3.5 新增】添加温度监控功能 - 修改为全自动
# ============================================================================
add_temperature_monitoring() {
    print_step "添加温度监控功能"
    
    local user_home="/home/$ACTUAL_USER"
    local monitor_script="$user_home/temp_monitor.sh"
    local service_file="/etc/systemd/system/temp-monitor.service"
    
    # 创建温度监控脚本
    cat > "$monitor_script" << 'EOF'
#!/bin/bash
# 树莓派温度监控脚本 v3.5.1
# 自动监控CPU温度并在过高时发出警告

USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
LOG_FILE="$USER_HOME/temp_monitor.log"
MAX_TEMP=75  # 最大安全温度（摄氏度）
CRITICAL_TEMP=80  # 临界温度（摄氏度）
CHECK_INTERVAL=10  # 检查间隔（秒）

# 创建日志文件
mkdir -p "$(dirname "$LOG_FILE")"
echo "温度监控启动于 $(date)" >> "$LOG_FILE"

while true; do
    # 获取当前温度
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
    
    # 获取当前时间
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 检查温度是否过高
    if [ "$temp" != "N/A" ]; then
        # 使用awk进行浮点数比较（比bc更稳定）
        temp_compare=$(echo "$temp" | awk '{printf "%.1f", $1}')
        
        # 检查临界温度
        if (( $(echo "$temp_compare >= $CRITICAL_TEMP" | bc -l 2>/dev/null) )); then
            echo "CRITICAL: $timestamp - 温度过高！当前温度: ${temp}°C" >> "$LOG_FILE"
            # 尝试向所有用户发送警告
            if command -v wall > /dev/null; then
                echo "CRITICAL: $timestamp - CPU温度过高！当前: ${temp}°C" | wall 2>/dev/null || true
            fi
        # 检查警告温度
        elif (( $(echo "$temp_compare >= $MAX_TEMP" | bc -l 2>/dev/null) )); then
            echo "WARNING: $timestamp - 温度较高！当前温度: ${temp}°C" >> "$LOG_FILE"
        fi
        
        # 记录到日志（每分钟记录一次，而不是每小时）
        if [ $(date +%S) -lt 10 ]; then
            echo "INFO: $timestamp - 当前温度: ${temp}°C" >> "$LOG_FILE"
        fi
    fi
    
    sleep $CHECK_INTERVAL
done
EOF
    
    chmod +x "$monitor_script"
    print_success "温度监控脚本已创建: $monitor_script"
    
    # 在全自动模式下自动创建systemd服务
    if [ "$AUTO_MODE" = true ]; then
        print_info "全自动模式：自动创建温度监控服务"
        
        # 创建systemd服务文件
        sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=Raspberry Pi Temperature Monitor
After=multi-user.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash $monitor_script
Restart=always
RestartSec=10
User=$ACTUAL_USER
Group=$ACTUAL_USER
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
        
        # 启用服务
        sudo systemctl daemon-reload
        sudo systemctl enable temp-monitor.service 2>/dev/null
        sudo systemctl start temp-monitor.service
        
        sleep 2  # 给服务启动时间
        
        if systemctl is-active temp-monitor.service >/dev/null 2>&1; then
            print_success "温度监控服务已启用并启动"
            add_to_report "温度监控: ✓ 已启用 (systemd服务)"
        else
            print_warning "温度监控服务启动失败，请手动运行: $monitor_script"
            print_info "查看服务状态: sudo systemctl status temp-monitor.service"
            add_to_report "温度监控: ⚠ 脚本已创建，服务启动失败"
        fi
    else
        # 交互模式下询问用户
        read -p "是否创建自动启动的温度监控服务？(y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            # 创建systemd服务文件
            sudo tee "$service_file" > /dev/null << EOF
[Unit]
Description=Raspberry Pi Temperature Monitor
After=multi-user.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/bin/bash $monitor_script
Restart=always
RestartSec=10
User=$ACTUAL_USER
Group=$ACTUAL_USER
StandardOutput=null
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
            
            # 启用服务
            sudo systemctl daemon-reload
            sudo systemctl enable temp-monitor.service 2>/dev/null
            sudo systemctl start temp-monitor.service
            
            sleep 2  # 给服务启动时间
            
            if systemctl is-active temp-monitor.service >/dev/null 2>&1; then
                print_success "温度监控服务已启用并启动"
                add_to_report "温度监控: ✓ 已启用 (systemd服务)"
            else
                print_warning "温度监控服务启动失败，请手动运行: $monitor_script"
                print_info "查看服务状态: sudo systemctl status temp-monitor.service"
                add_to_report "温度监控: ⚠ 脚本已创建，服务启动失败"
            fi
        else
            print_info "温度监控脚本已创建，可手动运行: $monitor_script"
            add_to_report "温度监控: ✓ 脚本已创建"
        fi
    fi
    
    # 创建快速温度检查命令别名
    echo -e "\n# 温度监控别名" >> "$user_home/.bashrc"
    echo "alias temp='vcgencmd measure_temp 2>/dev/null || cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk \"{printf \\\"温度: %.1f°C\\\", \\\$1/1000}\"'" >> "$user_home/.bashrc"
    echo "alias temp-log='tail -20 ~/temp_monitor.log 2>/dev/null || echo \"日志文件不存在\"'" >> "$user_home/.bashrc"
    echo "alias temp-monitor='sudo systemctl status temp-monitor.service 2>/dev/null || echo \"温度监控服务未运行\"'" >> "$user_home/.bashrc"
    
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
    
    print_info "测试内存速度..."
    local mem_speed=$(dd if=/dev/zero of=/dev/null bs=1M count=500 2>&1 | tail -1 | awk '{print $8}')
    echo "  内存速度: ${mem_speed:-"测试失败"}"
    
    print_info "测试SD卡写入速度..."
    local test_file="/tmp/test_$(date +%s).bin"
    local disk_speed=$(dd if=/dev/zero of="$test_file" bs=1M count=50 oflag=direct 2>&1 | tail -1)
    rm -f "$test_file"
    echo "  磁盘速度: $disk_speed"
    
    print_info "获取实时系统状态："
    local temp=$(vcgencmd measure_temp)
    local volts=$(vcgencmd measure_volts)
    local clock=$(vcgencmd measure_clock arm | awk -F= '{printf "%.0f MHz", $2/1000000}')
    echo "  温度: $temp"
    echo "  电压: $volts"
    echo "  CPU频率: $clock"
    
    # 检查超频后的状态
    if [ "$PERFORMANCE_MODE" = true ] && [ "$OVERCLOCK_LEVEL" -gt 0 ]; then
        echo -e "\n${CYAN}超频状态检查：${NC}"
        
        # 检查实际运行频率
        local actual_clock=$(vcgencmd measure_clock arm | awk -F= '{printf "%.0f", $2/1000000}')
        local target_clock=0
        
        case $OVERCLOCK_LEVEL in
            1) target_clock=1750 ;;
            2) target_clock=1950 ;;
            3) target_clock=2100 ;;
        esac
        
        if [ $target_clock -gt 0 ] && [ $actual_clock -ge $((target_clock - 100)) ]; then
            print_success "CPU频率已达到目标: ${actual_clock}MHz"
        else
            print_warning "CPU频率未达目标: ${actual_clock}MHz (目标: ${target_clock}MHz)"
            print_info "可能需要重启或检查散热"
        fi
    fi
    
    add_to_report "=== 性能测试 ==="
    add_to_report "CPU测试: 完成"
    add_to_report "内存速度: ${mem_speed:-"N/A"}"
    add_to_report "磁盘速度: $(echo $disk_speed | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10}')"
    add_to_report "系统状态: $temp, $volts, $clock"
    
    print_success "性能测试完成"
}

# ============================================================================
# 【v3.5 新增】恢复默认设置功能
# ============================================================================
restore_backups() {
    print_step "恢复默认设置选项"
    
    echo -e "${YELLOW}此功能将恢复所有备份的配置文件：${NC}"
    echo "  1) 恢复软件源配置"
    echo "  2) 恢复超频设置"
    echo "  3) 恢复所有配置"
    echo "  4) 查看备份文件"
    echo "  5) 取消"
    
    read -p "请选择 (1-5): " -n 1 restore_choice
    echo
    
    case $restore_choice in
        1)
            # 恢复软件源
            if ls /etc/apt/sources.list.backup.* >/dev/null 2>&1; then
                local latest_backup=$(ls -t /etc/apt/sources.list.backup.* | head -1)
                sudo cp "$latest_backup" /etc/apt/sources.list
                print_success "软件源已恢复"
            else
                print_warning "未找到软件源备份"
            fi
            ;;
        2)
            # 恢复超频设置
            if ls /boot/config_backup_*.txt >/dev/null 2>&1; then
                local latest_backup=$(ls -t /boot/config_backup_*.txt | head -1)
                sudo cp "$latest_backup" /boot/config.txt
                print_success "超频设置已恢复，重启后生效"
            else
                print_warning "未找到超频配置备份"
            fi
            ;;
        3)
            # 恢复所有配置
            if ls /etc/apt/sources.list.backup.* >/dev/null 2>&1; then
                local latest_sources=$(ls -t /etc/apt/sources.list.backup.* | head -1)
                sudo cp "$latest_sources" /etc/apt/sources.list
                print_success "软件源已恢复"
            fi
            
            if ls /boot/config_backup_*.txt >/dev/null 2>&1; then
                local latest_config=$(ls -t /boot/config_backup_*.txt | head -1)
                sudo cp "$latest_config" /boot/config.txt
                print_success "超频设置已恢复"
            fi
            
            print_info "所有配置已恢复，建议重启系统"
            ;;
        4)
            # 查看备份文件
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
    local report_content="树莓派优化与验机报告\n生成时间: $(date)\n脚本版本: v3.5\n脚本模式: $([ "$AUTO_MODE" = true ] && echo "全自动模式" || echo "交互模式")\n"
    report_content+="========================================\n"
    report_content+="$REPORT_DATA"
    
    # 添加总结
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
    
    # 写入文件
    echo -e "$report_content" > "$report_file"
    
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
        
        # 显示报告部分内容
        echo -e "\n${GREEN}报告摘要：${NC}"
        head -n 30 "$report_file"
    else
        print_error "报告生成失败"
    fi
}

# ============================================================================
# 重启选项（全自动模式将执行重启）- 修改为全自动
# ============================================================================
reboot_option() {
    echo -e "\n${YELLOW}========================================${NC}"
    
    # 询问是否执行恢复操作
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
        
        # 全自动模式：自动选择立即重启
        print_warning "系统将在30秒后自动重启，以使所有优化生效。"
        print_warning "如需取消，请立即按 ${RED}Ctrl+C${NC} 键中断。"
        echo -e "${YELLOW}========================================${NC}"
        
        # 30秒倒计时，可被Ctrl+C中断
        for i in {30..1}; do
            echo -ne "  \r${i}秒后自动重启..."
            sleep 1
        done
        
        echo -e "\n${GREEN}正在重启系统...${NC}"
        add_to_report "系统操作：已执行自动重启"
        sudo reboot
        
    else
        # 交互模式：询问用户
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
                print_info "系统将在10分钟后重启..."
                if command -v at &> /dev/null; then
                    echo "sudo shutdown -r +10" | at now +10 minutes
                    print_info "已安排延迟重启，可使用 'atq' 查看，'atrm <作业号>' 取消"
                else
                    print_warning "at 命令未安装，无法安排延迟重启"
                    print_info "请手动执行：sudo shutdown -r +10"
                fi
                ;;
            3)
                print_info "系统将在30分钟后重启..."
                if command -v at &> /dev/null; then
                    echo "sudo shutdown -r +30" | at now +30 minutes
                    print_info "已安排延迟重启，可使用 'atq' 查看，'atrm <作业号>' 取消"
                else
                    print_warning "at 命令未安装，无法安排延迟重启"
                    print_info "请手动执行：sudo shutdown -r +30"
                fi
                ;;
            4)
                print_info "您可以选择稍后手动重启：${GREEN}sudo reboot${NC}"
                print_info "或稍后使用命令：sudo shutdown -r +时间（分钟）"
                ;;
            5)
                echo -e "\n${CYAN}重启后建议检查：${NC}"
                echo "1. 检查温度：temp 或 vcgencmd measure_temp"
                echo "2. 检查频率：vcgencmd measure_clock arm"
                echo "3. 检查电源状态：vcgencmd get_throttled"
                echo "4. 检查中文输入法：按 Ctrl+Space 切换"
                echo "5. 检查服务状态：systemctl status temp-monitor.service"
                echo "6. 查看系统日志：dmesg | tail -20"
                echo "7. 检查超频状态：cat /boot/config.txt | grep -E 'over_voltage|arm_freq|gpu_freq'"
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
    # 初始化
    init_environment
    
    # 检查root权限
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}请使用sudo运行此脚本：${NC}"
        echo -e "${YELLOW}sudo bash $(basename "$0")${NC}"
        log_message "错误：未使用sudo运行"
        exit 1
    fi
    
    # 显示标题和模式选择
    print_header
    
    # 【v3.0 新增】立即询问性能优化选项
    ask_performance_optimization
    
    # 主流程
    detect_hardware
    configure_sources
    system_update
    storage_optimization
    memory_optimization
    
    # 【v3.0 新增】配置超频（在内存优化之后）
    configure_overclock
    
    chinese_support
    
    # 【v3.5 新增】添加温度监控
    add_temperature_monitoring
    
    performance_test
    generate_report
    reboot_option
    
    # 清理
    cleanup
    
    echo -e "\n${GREEN}脚本执行完成！感谢使用树莓派优化脚本 v3.5！${NC}"
    echo -e "${CYAN}如有问题，请查看日志文件：$LOG_FILE${NC}"
}

# 设置脚本退出时的清理操作
trap cleanup EXIT

# 运行主程序
main