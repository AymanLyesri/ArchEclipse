hl.env("HYPRCURSOR_SIZE", "24")

-- qt6ct provides the QPalette every Qt app consumes (Fusion), colored from
-- the coloreclipse-generated file in ~/.config/qt6ct/colors. Without this
-- var the qt6ct platform theme never activates, even after installing qt6ct.
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
