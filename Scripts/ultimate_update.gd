
extends "res://Scripts/open_world.gd"

# ============================================================
# YAHYA ADVENTURES - ULTIMATE MENU UPDATE
# Godot 4.4.1
# ============================================================

const HERO_IMAGE_PATH := "res://Assets/yahya_character.png"

var ultimate_layer: CanvasLayer
var ultimate_root: Control
var ultimate_content: VBoxContainer
var ultimate_title: Label
var ultimate_subtitle: Label
var ultimate_scroll: ScrollContainer

var intro_visible := true
var guide_visible := false
var achievements_visible := false


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
    # FIX: Keep root input active while the scene tree is paused.
    process_mode = Node.PROCESS_MODE_ALWAYS

    super._ready()
    _create_ultimate_interface()
    _show_intro_screen()


func _create_ultimate_interface() -> void:
    ultimate_layer = CanvasLayer.new()
    ultimate_layer.name = "UltimateMenuLayer"
    ultimate_layer.layer = 200
    ultimate_layer.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(ultimate_layer)

    ultimate_root = Control.new()
    ultimate_root.name = "UltimateRoot"
    ultimate_root.set_anchors_and_offsets_preset(
        Control.PRESET_FULL_RECT
    )
    ultimate_root.process_mode = Node.PROCESS_MODE_ALWAYS
    ultimate_root.mouse_filter = Control.MOUSE_FILTER_STOP
    ultimate_layer.add_child(ultimate_root)


# ============================================================
# GENERAL UI HELPERS
# ============================================================

func _clear_ultimate_screen() -> void:
    for child in ultimate_root.get_children():
        child.queue_free()

    ultimate_content = null
    ultimate_scroll = null


func _make_ultimate_button(
    caption: String,
    callback: Callable
) -> Button:
    var button := Button.new()
    button.text = caption
    button.custom_minimum_size = Vector2(0, 58)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_filter = Control.MOUSE_FILTER_STOP

    button.add_theme_font_size_override("font_size", 21)
    button.add_theme_color_override(
        "font_color", Color(1.0, 0.97, 0.85)
    )
    button.add_theme_color_override(
        "font_pressed_color", Color(1.0, 0.85, 0.35)
    )

    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.035, 0.12, 0.22, 0.96)
    normal.border_color = Color(0.25, 0.72, 1.0)
    normal.set_border_width_all(2)
    normal.set_corner_radius_all(15)
    normal.content_margin_left = 12
    normal.content_margin_right = 12

    var pressed := StyleBoxFlat.new()
    pressed.bg_color = Color(0.30, 0.20, 0.06, 1.0)
    pressed.border_color = Color(1.0, 0.82, 0.25)
    pressed.set_border_width_all(3)
    pressed.set_corner_radius_all(15)

    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", normal)
    button.add_theme_stylebox_override("pressed", pressed)

    button.pressed.connect(callback)
    return button


func _make_ultimate_label(
    caption: String,
    font_size: int,
    color: Color
) -> Label:
    var label := Label.new()
    label.text = caption
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    return label


func _make_screen_container() -> VBoxContainer:
    var background := ColorRect.new()
    background.name = "ScreenBackground"
    background.color = Color(0.025, 0.055, 0.10, 0.97)
    background.set_anchors_and_offsets_preset(
        Control.PRESET_FULL_RECT
    )
    background.mouse_filter = Control.MOUSE_FILTER_STOP
    ultimate_root.add_child(background)

    var margin := MarginContainer.new()
    margin.set_anchors_and_offsets_preset(
        Control.PRESET_FULL_RECT
    )
    margin.add_theme_constant_override("margin_left", 22)
    margin.add_theme_constant_override("margin_right", 22)
    margin.add_theme_constant_override("margin_top", 18)
    margin.add_theme_constant_override("margin_bottom", 18)
    background.add_child(margin)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 12)
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.size_flags_vertical = Control.SIZE_EXPAND_FILL
    margin.add_child(box)

    ultimate_content = box
    return box


func _add_screen_title(
    heading: String,
    subtitle: String
) -> void:
    ultimate_title = _make_ultimate_label(
        heading, 30, Color(1.0, 0.82, 0.24)
    )
    ultimate_content.add_child(ultimate_title)

    ultimate_subtitle = _make_ultimate_label(
        subtitle, 16, Color(0.78, 0.88, 1.0)
    )
    ultimate_content.add_child(ultimate_subtitle)


func _add_back_button() -> void:
    ultimate_content.add_child(
        _make_ultimate_button(
            "العودة إلى القائمة الرئيسية",
            _show_intro_screen
        )
    )


# ============================================================
# INTRO SCREEN
# ============================================================

func _show_intro_screen() -> void:
    intro_visible = true
    guide_visible = false
    achievements_visible = false

    # FIX: Stop gameplay while keeping input active.
    is_game_paused = true
    get_tree().paused = true

    _clear_ultimate_screen()

    var box := _make_screen_container()

    box.add_child(
        _make_ultimate_label(
            "YAHYA ADVENTURES",
            34,
            Color(1.0, 0.80, 0.18)
        )
    )

    box.add_child(
        _make_ultimate_label(
            "مغامرات يحيى",
            32,
            Color.WHITE
        )
    )

    var portrait := TextureRect.new()
    portrait.custom_minimum_size = Vector2(0, 210)
    portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
    portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE

    if ResourceLoader.exists(HERO_IMAGE_PATH):
        var hero_texture := load(HERO_IMAGE_PATH) as Texture2D
        if hero_texture != null:
            portrait.texture = hero_texture

    box.add_child(portrait)

    box.add_child(
        _make_ultimate_label(
            "استعد لاكتشاف العالم وجمع الكنوز والبلورات!",
            17,
            Color(0.83, 0.91, 1.0)
        )
    )

    box.add_child(
        _make_ultimate_button(
            "▶  ابدأ المغامرة",
            _start_adventure
        )
    )

    box.add_child(
        _make_ultimate_button(
            "📖  دليل المغامرة - 100 عنصر",
            _show_guide_screen
        )
    )

    box.add_child(
        _make_ultimate_button(
            "🏆  إنجازات المغامرة",
            _show_achievements_screen
        )
    )

    box.add_child(
        _make_ultimate_label(
            "إصدار المغامرة",
            13,
            Color(0.55, 0.68, 0.82)
        )
    )


func _start_adventure() -> void:
    print("SMOKE_TEST: adventure_started")
    intro_visible = false
    guide_visible = false
    achievements_visible = false

    # FIX: Resume gameplay when the start button is pressed.
    is_game_paused = false

    _clear_ultimate_screen()
    ultimate_root.visible = false

    get_tree().paused = false


# ============================================================
# GUIDE - EXACTLY 100 ENTRIES
# ============================================================

func _get_guide_groups() -> Array:
    return [
        {
            "title": "المجموعة الأولى: الحركة والتحكم",
            "items": [
                "01 - تحريك يحيى إلى الأمام.",
                "02 - تحريك يحيى إلى الخلف.",
                "03 - التحرك إلى اليمين.",
                "04 - التحرك إلى اليسار.",
                "05 - استخدام أزرار الاتجاهات.",
                "06 - الجمع بين أكثر من اتجاه.",
                "07 - القفز فوق العوائق.",
                "08 - استخدام زر الركض.",
                "09 - مراقبة مستوى الطاقة.",
                "10 - استعادة الطاقة بعد الركض.",
                "11 - تغيير اتجاه الشخصية.",
                "12 - متابعة حركة الشخصية.",
                "13 - استخدام الكاميرا خلف البطل.",
                "14 - تقريب الكاميرا.",
                "15 - إبعاد الكاميرا.",
                "16 - استخدام زر الإيقاف المؤقت.",
                "17 - استئناف اللعب.",
                "18 - التحكم باللمس على الهاتف.",
                "19 - الضغط على أكثر من زر باللمس.",
                "20 - تجربة الحركة في المساحات المفتوحة."
            ]
        },
        {
            "title": "المجموعة الثانية: العالم والاستكشاف",
            "items": [
                "21 - استكشاف الحديقة.",
                "22 - التجول بين الأشجار.",
                "23 - مشاهدة المباني والعناصر المحيطة.",
                "24 - اكتشاف الطرق والمسارات.",
                "25 - زيارة منطقة النافورة.",
                "26 - الاقتراب من البستاني.",
                "27 - التحدث مع الشخصيات.",
                "28 - البحث عن صندوق الكنز.",
                "29 - اكتشاف البوابة السرية.",
                "30 - دخول المنطقة السرية بعد فتحها.",
                "31 - زيارة منطقة البركة.",
                "32 - استكشاف أماكن الراحة.",
                "33 - اكتشاف مواقع العملات.",
                "34 - البحث عن البلورات الزرقاء.",
                "35 - مراقبة المؤثرات المحيطة.",
                "36 - مشاهدة الإضاءة في الحديقة.",
                "37 - استكشاف المناطق البعيدة.",
                "38 - اكتشاف الأماكن المخفية.",
                "39 - متابعة الطريق إلى الكنز.",
                "40 - العودة إلى الأماكن التي تمت زيارتها."
            ]
        },
        {
            "title": "المجموعة الثالثة: العملات والمهام والكنوز",
            "items": [
                "41 - جمع العملات الذهبية.",
                "42 - متابعة عدد العملات.",
                "43 - جمع العملات الموجودة في الحديقة.",
                "44 - البحث عن البلورة الأولى.",
                "45 - البحث عن البلورة الثانية.",
                "46 - البحث عن البلورة الثالثة.",
                "47 - متابعة عدد البلورات.",
                "48 - بدء مهمة البستاني.",
                "49 - قراءة رسالة البستاني.",
                "50 - إكمال مهمة البلورات.",
                "51 - العودة إلى البستاني.",
                "52 - الحصول على مكافأة المهمة.",
                "53 - العثور على المفتاح الذهبي.",
                "54 - استخدام المفتاح مع صندوق الكنز.",
                "55 - فتح صندوق الكنز.",
                "56 - جمع مكافأة الصندوق.",
                "57 - فتح البوابة السرية.",
                "58 - البحث عن الكنز النادر.",
                "59 - جمع الكنز السري.",
                "60 - حفظ تقدم المغامرة."
            ]
        },
        {
            "title": "المجموعة الرابعة: المؤثرات والصوت",
            "items": [
                "61 - مشاهدة تأثير جمع العملة.",
                "62 - مشاهدة تأثير جمع البلورة.",
                "63 - مشاهدة تأثيرات المكافآت.",
                "64 - مشاهدة الشرارات السحرية.",
                "65 - ملاحظة حركة البلورات.",
                "66 - مشاهدة حركة مياه النافورة.",
                "67 - ملاحظة تغير الإضاءة.",
                "68 - الاستماع إلى أصوات العملات.",
                "69 - الاستماع إلى صوت البلورات.",
                "70 - الاستماع إلى صوت المفتاح.",
                "71 - الاستماع إلى صوت الكنز.",
                "72 - الاستماع إلى صوت المهمة.",
                "73 - الاستماع إلى أصوات التفاعل.",
                "74 - الاستماع إلى أصوات الماء.",
                "75 - الاستماع إلى أصوات الطيور.",
                "76 - الاستماع إلى أصوات الخطوات.",
                "77 - تجربة المؤثرات أثناء الحركة.",
                "78 - ملاحظة المؤثرات أثناء القفز.",
                "79 - مشاهدة تأثير فتح البوابة.",
                "80 - تجربة أجواء الحديقة."
            ]
        },
        {
            "title": "المجموعة الخامسة: الواجهة وتجربة اللعب",
            "items": [
                "81 - مشاهدة شاشة بداية المغامرة.",
                "82 - مشاهدة صورة البطل.",
                "83 - بدء اللعبة من القائمة.",
                "84 - فتح دليل المغامرة.",
                "85 - تصفح عناصر الدليل.",
                "86 - فتح قائمة الإنجازات.",
                "87 - العودة إلى القائمة الرئيسية.",
                "88 - استخدام واجهة الهاتف.",
                "89 - تجربة اللعب بوضع الشاشة العمودي.",
                "90 - تجربة اللعب بوضع الشاشة الأفقي.",
                "91 - متابعة رسالة المهمة.",
                "92 - متابعة مؤشر العملات.",
                "93 - متابعة مؤشر البلورات.",
                "94 - متابعة مؤشر الطاقة.",
                "95 - استخدام زر التفاعل.",
                "96 - استخدام زر القفز.",
                "97 - استخدام زر الركض.",
                "98 - استخدام أزرار الكاميرا.",
                "99 - إيقاف اللعبة مؤقتاً عند الحاجة.",
                "100 - الاستمتاع بمغامرة يحيى."
            ]
        }
    ]


func _show_guide_screen() -> void:
    intro_visible = false
    guide_visible = true
    achievements_visible = false

    _clear_ultimate_screen()

    var box := _make_screen_container()

    _add_screen_title(
        "دليل المغامرة",
        "100 عنصر وأفكار للاستكشاف والتجربة"
    )

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    box.add_child(scroll)

    ultimate_scroll = scroll

    var list_box := VBoxContainer.new()
    list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list_box.add_theme_constant_override("separation", 9)
    scroll.add_child(list_box)

    var groups := _get_guide_groups()

    for group_data in groups:
        var heading := _make_ultimate_label(
            str(group_data["title"]),
            21,
            Color(1.0, 0.82, 0.24)
        )
        heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        list_box.add_child(heading)

        for entry in group_data["items"]:
            var item_label := Label.new()
            item_label.text = str(entry)
            item_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
            item_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
            item_label.add_theme_font_size_override("font_size", 16)
            item_label.add_theme_color_override(
                "font_color", Color(0.90, 0.94, 1.0)
            )
            item_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            list_box.add_child(item_label)

        var separator := HSeparator.new()
        list_box.add_child(separator)

    _add_back_button()


# ============================================================
# ACHIEVEMENTS SCREEN
# ============================================================

func _get_achievement_list() -> Array[String]:
    return [
        "01 - بداية المغامرة: ابدأ اللعب.",
        "02 - المستكشف الصغير: تجول في العالم.",
        "03 - جامع العملات: اجمع عملة ذهبية.",
        "04 - جامع الكنوز: افتح صندوق الكنز.",
        "05 - صديق البستاني: تحدث مع البستاني.",
        "06 - بداية المهمة: ابدأ مهمة البلورات.",
        "07 - البلورة الأولى: اجمع البلورة الأولى.",
        "08 - البلورة الثانية: اجمع البلورة الثانية.",
        "09 - البلورة الثالثة: اجمع البلورة الثالثة.",
        "10 - بطل البلورات: أكمل مهمة البلورات.",
        "11 - صاحب المفتاح: اعثر على المفتاح الذهبي.",
        "12 - فاتح الصندوق: افتح صندوق الكنز.",
        "13 - مستكشف الأسرار: افتح البوابة السرية.",
        "14 - الباحث عن الكنز: اعثر على الكنز النادر.",
        "15 - صاحب المكافأة: اجمع مكافأة المهمة.",
        "16 - سريع الحركة: استخدم الركض.",
        "17 - القافز: نفذ قفزة.",
        "18 - المغامر: استكشف مناطق مختلفة.",
        "19 - محب الحديقة: زر النافورة.",
        "20 - بطل يحيى: أكمل رحلة الاستكشاف."
    ]


func _show_achievements_screen() -> void:
    intro_visible = false
    guide_visible = false
    achievements_visible = true

    _clear_ultimate_screen()

    var box := _make_screen_container()

    _add_screen_title(
        "إنجازات المغامرة",
        "20 هدفاً يمكنك العمل على تحقيقها أثناء اللعب"
    )

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    box.add_child(scroll)

    var list_box := VBoxContainer.new()
    list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list_box.add_theme_constant_override("separation", 12)
    scroll.add_child(list_box)

    for achievement in _get_achievement_list():
        var label := Label.new()
        label.text = "🏆  " + achievement
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        label.add_theme_font_size_override("font_size", 17)
        label.add_theme_color_override(
            "font_color", Color(1.0, 0.90, 0.56)
        )
        label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        list_box.add_child(label)

    _add_back_button()
