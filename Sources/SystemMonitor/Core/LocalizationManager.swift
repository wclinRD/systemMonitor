import Foundation
import SwiftUI

@MainActor
class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    @AppStorage("appLanguage") var language: String = "auto"
    
    private let zhHant: [String: String] = [
        "System Monitor": "系統監控",
        "General": "一般",
        "Menu Bar": "系統列",
        "Panel": "面板",
        "Network": "網路",
        "Upload": "上傳",
        "Download": "下載",
        "App Data Usage": "App 數據用量",
        "System": "系統",
        "Storage": "儲存空間",
        "Memory": "記憶體",
        "CPU Load": "CPU 負載",
        "Floating Window": "懸浮視窗",
        "Panel Opacity": "面板透明度",
        "Card Opacity": "卡片透明度",
        "Top Upload": "上傳排行",
        "Top Download": "下載排行",
        "About": "關於",
        "Launch at Login": "登入時自動啟動",
        "This will start SystemMonitor automatically when you log in.": "這將在您登入時自動啟動系統監控。",
        "Language": "語言",
        "Automatic": "自動",
        "Display": "顯示",
        "Opacity": "透明度",
        "Total Upload:": "總上傳:",
        "Total Download:": "總下載:",
        "Uploading Apps": "上傳應用程式",
        "Downloading Apps": "下載應用程式",
        "No active network usage": "無網路活動",
        "Settings": "設定",
        "Quit": "離開",
        "Version": "版本",
        "Build": "建置版本",
        "Menu Bar Transparency": "選單透明度",
        "App Display Count": "顯示數量",
        "All": "全部",
        "3 Items": "3 個",
        "5 Items": "5 個",
        "7 Items": "7 個",
        "10 Items": "10 個",
        "Quiet": "靜止",
        "Show Arrows": "顯示箭頭",
        "Arrow Position": "箭頭位置",
        "Left": "左側",
        "Right": "右側",
        "Show Decimals": "顯示小數點",
        "Unit Style": "單位樣式",
        "Upload Color": "上傳顏色",
        "Download Color": "下載顏色",
        "Panel Width": "面板寬度",
        "Text Format": "文字格式",
        "4 Digits": "四位數",
        "3 Digits": "三位數",
        "2 Digits + Decimal": "兩位數＋小數點",
        "Show Upload": "顯示上傳",
        "Show Download": "顯示下載",
        "App List Style": "列表樣式",
        "Icon Only": "僅圖示",
        "Name Only": "僅名稱",
        "Icon + Name": "圖示＋名稱"
    ]
    
    func localized(_ key: String) -> String {
        let currentLang: String
        if language == "auto" {
            let preferred = Locale.current.identifier
            if preferred.contains("Hant") || preferred.contains("TW") || preferred.contains("HK") {
                currentLang = "zh-Hant"
            } else {
                currentLang = "en"
            }
        } else {
            currentLang = language
        }
        
        if currentLang == "zh-Hant" {
            return zhHant[key] ?? key
        }
        
        return key
    }
}

extension String {
    @MainActor
    var localized: String {
        LocalizationManager.shared.localized(self)
    }
}
