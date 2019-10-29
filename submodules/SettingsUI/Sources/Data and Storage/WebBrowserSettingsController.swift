import Foundation
import UIKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import AccountContext
import OpenInExternalAppUI

private final class WebBrowserSettingsControllerArguments {
    let context: AccountContext
    let updateDefaultBrowser: (String?) -> Void
    
    init(context: AccountContext, updateDefaultBrowser: @escaping (String?) -> Void) {
        self.context = context
        self.updateDefaultBrowser = updateDefaultBrowser
    }
}

private enum WebBrowserSettingsSection: Int32 {
    case browsers
}

private enum WebBrowserSettingsControllerEntry: ItemListNodeEntry {
    case browserHeader(PresentationTheme, String)
    case browser(PresentationTheme, String, OpenInApplication, String?, Bool, Int32)
    
    var section: ItemListSectionId {
        switch self {
            case .browserHeader, .browser:
                return WebBrowserSettingsSection.browsers.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .browserHeader:
                return 0
            case let .browser(_, _, _, _, _, index):
                return 1 + index
        }
    }
    
    static func ==(lhs: WebBrowserSettingsControllerEntry, rhs: WebBrowserSettingsControllerEntry) -> Bool {
        switch lhs {
            case let .browserHeader(lhsTheme, lhsText):
                if case let .browserHeader(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .browser(lhsTheme, lhsTitle, lhsApplication, lhsIdentifier, lhsSelected, lhsIndex):
                if case let .browser(rhsTheme, rhsTitle, rhsApplication, rhsIdentifier, rhsSelected, rhsIndex) = rhs, lhsTheme === rhsTheme, lhsTitle == rhsTitle, lhsApplication == rhsApplication, lhsIdentifier == rhsIdentifier, lhsSelected == rhsSelected, lhsIndex == rhsIndex {
                    return true
                } else {
                    return false
                }
        }
    }
        
    static func <(lhs: WebBrowserSettingsControllerEntry, rhs: WebBrowserSettingsControllerEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(_ arguments: Any) -> ListViewItem {
        let arguments = arguments as! WebBrowserSettingsControllerArguments
        switch self {
            case let .browserHeader(theme, text):
                return ItemListSectionHeaderItem(theme: theme, text: text, sectionId: self.section)
            case let .browser(theme, title, application, identifier, selected, _):
                return WebBrowserItem(account: arguments.context.account, theme: theme, title: title, application: application, checked: selected, sectionId: self.section) {
                    arguments.updateDefaultBrowser(identifier)
                }
        }
    }
}

private func webBrowserSettingsControllerEntries(context: AccountContext, presentationData: PresentationData, selectedBrowser: String?) -> [WebBrowserSettingsControllerEntry] {
    var entries: [WebBrowserSettingsControllerEntry] = []
    
    let options = availableOpenInOptions(context: context, item: .url(url: "http://telegram.org"))
    
    entries.append(.browserHeader(presentationData.theme, presentationData.strings.WebBrowser_DefaultBrowser))
    entries.append(.browser(presentationData.theme, presentationData.strings.WebBrowser_InAppSafari, .safari, nil, selectedBrowser == nil, 0))
    
    var index: Int32 = 1
    for option in options {
        entries.append(.browser(presentationData.theme, option.title, option.application, option.identifier, option.identifier == selectedBrowser, index))
        index += 1
    }
    
    return entries
}

public func webBrowserSettingsController(context: AccountContext) -> ViewController {
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    
    let updateDisposable = MetaDisposable()
    let arguments = WebBrowserSettingsControllerArguments(context: context, updateDefaultBrowser: { identifier in
        let _ = updateWebBrowserSettingsInteractively(accountManager: context.sharedContext.accountManager, { $0.withUpdatedDefaultWebBrowser(identifier) }).start()
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, context.sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.webBrowserSettings]))
    |> deliverOnMainQueue
    |> map { presentationData, sharedData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let settings = (sharedData.entries[ApplicationSpecificSharedDataKeys.webBrowserSettings] as? WebBrowserSettings) ?? WebBrowserSettings.defaultSettings
        
        let controllerState = ItemListControllerState(theme: presentationData.theme, title: .text(presentationData.strings.WebBrowser_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(entries: webBrowserSettingsControllerEntries(context: context, presentationData: presentationData, selectedBrowser: settings.defaultWebBrowser), style: .blocks, animateChanges: false)
        
        return (controllerState, (listState, arguments))
    }
    
    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
