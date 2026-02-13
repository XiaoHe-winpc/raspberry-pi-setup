#!/bin/bash
# ============================================================================
# 树莓派智能优化脚本 v3.0
# 作者：小何-winp电脑（XiaoHe_winpc）
# 功能：硬件验机 + 系统优化 + 中文支持 + 性能测试 + 智能超频
# 特点：1. 全自动模式（输入A） | 2. 交互模式
#       3. 全自动模式下智能判断是否安装中文支持
#       4. 新增智能超频与综合性能优化选项
# 使用方法：sudo bash v3.sh
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

# ============================================================================
# 工具函数
# ============================================================================

# 初始化环境
init_environment() {
    mkdir -p "$TEMP_DIR"
    exec 2> >(tee -a "$LOG_FILE")
}

# 记录日志
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

print_header() {
    clear
    echo -e "${CYAN}"
    echo "================================================"
    echo "      树莓派智能优化与验机脚本 v3.0"
    echo "================================================"
    echo -e "${NC}"
    echo -e "${PURPLE}新增特性：智能超频 + 综合性能优化${NC}"
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
# 【v3.0 新增】性能优化选项询问（在模式选择后立即执行）
# ============================================================================
ask_performance_optimization() {
    print_step "性能优化选项"
    
    echo -e "${PURPLE}================================================${NC}"
    echo -e "${CYAN}        性能优化选项（新增 v3.0 功能）${NC}"
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
    
    # 询问是否启用性能优化
    if [ "$AUTO_MODE" = true ]; then
        echo -e "${BLUE}全自动模式：正在询问性能优化选项${NC}"
    fi
    
    read -p "是否启用性能优化（包括超频）？(y/N): " -n 1 enable_perf
    echo ""
    
    if [[ $enable_perf =~ ^[Yy]$ ]]; then
        PERFORMANCE_MODE=true
        
        # 询问超频级别
        echo ""
        echo -e "${CYAN}请选择超频级别：${NC}"
        echo "  [0] 不超频 - 仅进行安全的软件优化"
        echo "  [1] 保守超频 (1750MHz) - 稳定性优先，适合所有设备"
        echo "  [2] 平衡超频 (1950MHz) - 性能与稳定兼顾，需要基本散热"
        echo "  [3] 激进超频 (2100MHz) - 极致性能，必须配备风扇和优质电源"
        echo ""
        echo -e "${GREEN}推荐：${NC}多数用户选择【2】平衡超频，可获得最佳体验。"
        
        if [ "$AUTO_MODE" = true ]; then
            echo -e "${BLUE}全自动模式：建议选择级别 2（平衡超频）${NC}"
            read -p "请输入选择 (0-3，默认2): " oc_level
        else
            read -p "请输入选择 (0-3，默认2): " oc_level
        fi
        
        # 设置默认值并验证范围
        oc_level=${oc_level:-2}
        if [[ ! "$oc_level" =~ ^[0-3]$ ]]; then
            print_warning "输入无效，使用默认值：平衡超频 (级别2)"
            oc_level=2
        fi
        
        OVERCLOCK_LEVEL=$oc_level
        
        # 根据级别显示警告
        case $oc_level in
            0)
                print_info "已选择：不超频，仅进行软件优化"
                ;;
            1)
                print_info "已选择：保守超频 (1750MHz)"
                ;;
            2)
                print_warning "已选择：平衡超频 (1950MHz) - 请确保散热良好"
                ;;
            3)
                print_warning "已选择：激进超频 (2100MHz) - 需要优秀的散热条件！"
                echo -e "${YELLOW}      如出现不稳定，请恢复默认设置。${NC}"
                ;;
        esac
        
        add_to_report "性能优化: 已启用 (级别 $oc_level)"
        log_message "用户启用性能优化，级别: $oc_level"
    else
        PERFORMANCE_MODE=false
        OVERCLOCK_LEVEL=0
        print_info "跳过性能优化"
        add_to_report "性能优化: 已跳过"
        log_message "用户跳过性能优化"
    fi
    
    # 保存性能配置供后续步骤使用
    echo "PERFORMANCE_MODE=$PERFORMANCE_MODE" > "$TEMP_DIR/performance.conf"
    echo "OVERCLOCK_LEVEL=$OVERCLOCK_LEVEL" >> "$TEMP_DIR/performance.conf"
}

# ============================================================================
# 智能网络检测函数
# ============================================================================
detect_network_environment() {
    print_info "正在检测网络环境以优化配置..."
    
    local china_test_urls=(
        "http://www.baidu.com"
        "http://connectivity-check.ubuntu.com"
        "http://captive.apple.com"
    )
    
    IS_IN_CHINA=false
    local timeout=3
    local success_count=0
    
    for url in "${china_test_urls[@]}"; do
        if curl -s --max-time $timeout --retry 1 "$url" > /dev/null 2>&1; then
            success_count=$((success_count + 1))
        fi
    done
    
    # 如果至少有两个测试成功，判断为国内环境
    if [ $success_count -ge 2 ]; then
        IS_IN_CHINA=true
        print_success "检测到中国网络环境"
        print_info "将为中国用户优化配置（中文支持、国内镜像源）"
        add_to_report "网络环境: 中国境内"
    else
        IS_IN_CHINA=false
        print_info "Detected international network environment"
        print_info "将使用国际通用配置"
        add_to_report "网络环境: 国际网络"
    fi
    
    # 保存检测结果供后续使用
    echo "IS_IN_CHINA=$IS_IN_CHINA" > "$TEMP_DIR/network_env"
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
# 【v3.0 新增】配置超频函数（在内存优化后执行）
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
    
    print_step "配置超频设置 (级别 $OVERCLOCK_LEVEL)"
    
    # 备份原始配置文件
    local config_backup="/boot/config_backup_$(date +%Y%m%d_%H%M%S).txt"
    sudo cp /boot/config.txt "$config_backup" 2>/dev/null
    print_info "已备份原始配置: $config_backup"
    
    # 根据级别设置不同的参数
    case $OVERCLOCK_LEVEL in
        1) # 保守超频
            print_info "应用保守超频设置..."
            sudo tee -a /boot/config.txt > /dev/null << EOF

# 保守超频设置 (v3.0脚本)
over_voltage=2
arm_freq=1750
gpu_freq=550
EOF
            ;;
        2) # 平衡超频
            print_info "应用平衡超频设置..."
            sudo tee -a /boot/config.txt > /dev/null << EOF

# 平衡超频设置 (v3.0脚本)
over_voltage=4
arm_freq=1950
gpu_freq=600
EOF
            ;;
        3) # 激进超频
            print_warning "应用激进超频设置，请确保散热良好！"
            sudo tee -a /boot/config.txt > /dev/null << EOF

# 激进超频设置 (v3.0脚本) - 需要优秀散热！
over_voltage=6
arm_freq=2100
gpu_freq=700
force_turbo=1
EOF
            ;;
    esac
    
    if [ $? -eq 0 ]; then
        print_success "超频设置已应用 (级别 $OVERCLOCK_LEVEL)"
        print_warning "⚠️  需要重启系统才能生效！"
        add_to_report "超频设置: ✓ 已应用 (级别 $OVERCLOCK_LEVEL)"
        log_message "超频设置应用成功，级别: $OVERCLOCK_LEVEL"
    else
        print_error "超频设置失败"
        add_to_report "超频设置: ✗ 失败"
        log_message "超频设置失败"
    fi
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
    
    add_to_report "=== 性能测试 ==="
    add_to_report "CPU测试: 完成"
    add_to_report "内存速度: ${mem_speed:-"N/A"}"
    add_to_report "磁盘速度: $(echo $disk_speed | awk '{print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10}')"
    add_to_report "系统状态: $temp, $volts, $clock"
    
    print_success "性能测试完成"
}

# ============================================================================
# 生成报告
# ============================================================================
generate_report() {
    print_step "生成优化报告"
    
    local report_file="$HOME/pi_optimization_report_$(date +%Y%m%d_%H%M%S).txt"
    local report_content="树莓派优化与验机报告\n生成时间: $(date)\n脚本版本: v3.0\n脚本模式: $([ "$AUTO_MODE" = true ] && echo "全自动模式" || echo "交互模式")\n"
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
    report_content+="5. 建议定期检查系统更新：sudo apt update && sudo apt upgrade\n"
    report_content+="6. 监控温度命令：vcgencmd measure_temp\n"
    
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
        echo "4. 查看完整报告：cat $report_file"
        echo -e "${YELLOW}========================================${NC}"
        
        # 显示报告部分内容
        echo -e "\n${GREEN}报告摘要：${NC}"
        head -n 30 "$report_file"
    else
        print_error "报告生成失败"
    fi
}

# ============================================================================
# 重启选项（全自动模式将执行重启）
# ============================================================================
reboot_option() {
    echo -e "\n${YELLOW}========================================${NC}"
    
    if [ "$AUTO_MODE" = true ]; then
        print_info "全自动模式执行完成！"
        print_warning "系统将在15秒后自动重启，以使所有优化生效。"
        print_warning "如需取消，请立即按 ${RED}Ctrl+C${NC} 键中断。"
        echo -e "${YELLOW}========================================${NC}"
        
        # 15秒倒计时，可被Ctrl+C中断
        for i in {15..1}; do
            echo -ne "  \r${i}秒后自动重启..."
            sleep 1
        done
        
        echo -e "\n${GREEN}正在重启系统...${NC}"
        add_to_report "系统操作：已执行自动重启"
        sudo reboot
        
    else
        # 交互模式：询问用户
        print_info "部分优化（如文件系统扩展、中文支持、超频设置）需要重启才能完全生效。"
        read -p "是否立即重启系统？(y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "系统将在10秒后重启，按 Ctrl+C 取消..."
            for i in {10..1}; do
                echo -ne "  \r${i}秒后重启..."
                sleep 1
            done
            echo -e "\n正在重启系统..."
            sudo reboot
        else
            print_info "您可以选择稍后手动重启：${GREEN}sudo reboot${NC}"
        fi
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
    performance_test
    generate_report
    reboot_option
    
    # 清理
    cleanup
    
    echo -e "\n${GREEN}脚本执行完成！感谢使用树莓派优化脚本 v3.0！${NC}"
}

# 运行主程序
main