//
//  SBAProfileSection.swift
//  BridgeApp
//
//  Copyright © 2017-2018 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation
import HealthKit

/// The type of a profile table item. This is used to decode the item in a factory.
public struct SBAProfileTableItemType : RawRepresentable, Codable {
    public typealias RawValue = String
    
    public private(set) var rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    /// Defaults to creating a `SBAHTMLProfileTableItem`.
    public static let html: SBAProfileTableItemType = "html"
    
    /// Defaults to creating a `SBAProfileItemProfileTableItem`.
    public static let profileItem: SBAProfileTableItemType = "profileItem"
    
    /// Defaults to creating a `SBAResourceProfileTableItem`.
    public static let resource: SBAProfileTableItemType = "resource"

    /// List of all the standard types.
    public static func allStandardTypes() -> [SBAProfileTableItemType] {
        return [.html, .profileItem, .resource]
    }
}

extension SBAProfileTableItemType : Equatable {
    public static func ==(lhs: SBAProfileTableItemType, rhs: SBAProfileTableItemType) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    public static func ==(lhs: String, rhs: SBAProfileTableItemType) -> Bool {
        return lhs == rhs.rawValue
    }
    public static func ==(lhs: SBAProfileTableItemType, rhs: String) -> Bool {
        return lhs.rawValue == rhs
    }
}

extension SBAProfileTableItemType : Hashable {
    public var hashValue : Int {
        return self.rawValue.hashValue
    }
}

extension SBAProfileTableItemType : ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

extension SBAProfileTableItemType {
    static func allCodingKeys() -> [String] {
        return allStandardTypes().map{ $0.rawValue }
    }
}

/// A protocol for defining a section of a profile table.
public protocol SBAProfileSection {
    /// The title text to show for the section.
    var title: String? { get }
    
    /// An icon to show in the section header.
    var icon: String? { get }
    
    /// A list of profile table items to show in the section.
    var items: [SBAProfileTableItem] { get }
}

/// A protocol for defining items to be shown in a profile table.
public protocol SBAProfileTableItem {
    /// The title text to show for the item.
    var title: String? { get }
    
    /// Detail text to show for the item.
    var detail: String? { get }
    
    /// Is the table item editable?
    var isEditable: Bool? { get }
    
    /// A set of cohorts (data groups) the participant must be in, in order to show this item in its containing profile section.
    var inCohorts: Set<String>? { get }
    
    /// A set of cohorts (data groups) the participant must **not** be in, in order to show this item in its containing profile section.
    var notInCohorts: Set<String>? { get }
    
    /// The action to perform when the item is selected.
    var onSelected: SBAProfileOnSelectedAction? { get }
}

/// A concrete implementation of the `SBAProfileSection` protocol which implements the Decodable protocol so it can be described in JSON.
open class SBAProfileSectionObject: SBAProfileSection, Decodable {
    open var title: String?
    open var icon: String?
    private var allItems: [SBAProfileTableItem] = []
    open var items: [SBAProfileTableItem] {
        get {
            
            let cohorts = SBAParticipantManager.shared.studyParticipant?.dataGroups ?? Set<String>()
            return allItems.filter({ (tableItem) -> Bool in
                // return true if participant data groups include all of the inCohorts and none of the notInCohorts
                guard tableItem.inCohorts != nil || tableItem.notInCohorts != nil
                    else {
                        return true
                }
                let mustBeIn = tableItem.inCohorts ?? Set<String>()
                let mustNotBeIn = tableItem.notInCohorts ?? Set<String>()
                return (mustBeIn.intersection(cohorts) == mustBeIn &&
                        mustNotBeIn.isDisjoint(with: cohorts))
            })
        }
        set {
            allItems = newValue
        }
    }
    
    // MARK: Decoder
    private enum CodingKeys: String, CodingKey {
        case title, icon, items
    }

    private enum TypeKeys: String, CodingKey {
        case type
    }
    
    /// Get a string that will identify the type of object to instantiate for the given decoder.
    ///
    /// By default, this will look in the container for the decoder for a key/value pair where
    /// the key == "type" and the value is a `String`.
    ///
    /// - parameter decoder: The decoder to inspect.
    /// - returns: The string representing this class type (if found).
    /// - throws: `DecodingError` if the type name cannot be decoded.
    func typeName(from decoder:Decoder) throws -> String {
        let container = try decoder.container(keyedBy: TypeKeys.self)
        return try container.decode(String.self, forKey: .type)
    }
    
    public required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decodeIfPresent(String.self, forKey: .title)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        if container.contains(.items) {
            var items: [SBAProfileTableItem] = []
            var nestedContainer = try container.nestedUnkeyedContainer(forKey: .items)
            while !nestedContainer.isAtEnd {
                let itemDecoder = try nestedContainer.superDecoder()
                let itemTypeName = try typeName(from: itemDecoder)
                let itemType = SBAProfileTableItemType(rawValue: itemTypeName)
                if let item = try decodeItem(from: itemDecoder, with: itemType) {
                    items.append(item)
                }
            }
            self.items = items
        }
    }

    /// Decode the profile table item from this decoder.
    ///
    /// - parameters:
    ///     - type:        The `ProfileTableItemType` to instantiate.
    ///     - decoder:     The decoder to use to instatiate the object.
    /// - returns: The profile item (if any) created from this decoder.
    /// - throws: `DecodingError` if the object cannot be decoded.
    open func decodeItem(from decoder:Decoder, with type:SBAProfileTableItemType) throws -> SBAProfileTableItem? {
        
        switch (type) {
        case .html:
            return try SBAHTMLProfileTableItem(from: decoder)
        case .profileItem:
            return try SBAProfileItemProfileTableItem(from: decoder)
            // TODO: emm 2018-08-19 deal with this for mPower 2 2.1
//        case .resource:
//            return try SBAResourceProfileTableItem(from: decoder)
        default:
            assertionFailure("Attempt to decode profile table item of unknown type \(type.rawValue)")
            return nil
        }
    }

}

/// A profile table item that displays HTML when selected.
public struct SBAHTMLProfileTableItem: SBAProfileTableItem, Decodable, RSDResourceTransformer {
    private enum CodingKeys: String, CodingKey {
        case title, detail, inCohorts, notInCohorts, htmlResource, bundleIdentifier
    }
    
    // MARK: SBAProfileTableItem
    /// Title to show for the table item.
    public var title: String?
    
    /// Detail text to show for the table item.
    public var detail: String?
    
    /// HTML profile table items are not editable.
    public var isEditable: Bool? {
        return false
    }
    
    /// A set of cohorts (data groups) the participant must be in, in order to show this item in its containing profile section.
    public var inCohorts: Set<String>?
    
    /// A set of cohorts (data groups) the participant must not be in, in order to show this item in its containing profile section.
    public var notInCohorts: Set<String>?
    
    /// HTML items show the HTML when selected.
    public var onSelected: SBAProfileOnSelectedAction? {
        return .showHTML
    }
    
    // MARK: HTML Profile Table Item
    
    /// The htmlResource for this item.
    public let htmlResource: String
    
    /// Get a URL pointer to the HTML resource.
    public var url: URL? {
        do {
            let (url,_) = try self.resourceURL(ofType: "html")
            return url
        }
        catch let err {
            debugPrint("Error getting the URL: \(err)")
            return nil
        }
    }
    
    
    // MARK: RSDResourceTransformer
    
    /// The bundle identifier for the resource bundle that contains the html.
    public var bundleIdentifier: String?
    
    /// The default bundle from the factory used to decode this object.
    public var factoryBundle: Bundle? = nil
    
    /// `RSDResourceTransformer` uses this to get the URL.
    public var resourceName: String {
        return htmlResource
    }
    
    /// Ignored - required to conform to `RSDResourceTransformer`
    public var classType: String? {
        return nil
    }

}

/// A profile table item that displays, and allows editing, the value of a Profile Item.
public struct SBAProfileItemProfileTableItem: SBAProfileTableItem, Decodable {
    private enum CodingKeys: String, CodingKey {
        case title, _isEditable = "isEditable", inCohorts, notInCohorts, _onSelected = "onSelected", profileItemKey, editTaskIdentifier
    }
    // MARK: SBAProfileTableItem
    /// Title to show for the table item.
    public var title: String?
    
    /// Detail text to show for the table item.
    public var detail: String? {
        switch self.profileItem.itemType {
        case .base(.boolean):
            // Bool table items show detail as On/Off, or blank if never set
            guard let isOn = self.profileItemValue as? Bool else { return "" }
            return isOn ? Localization.localizedString("SETTINGS_STATE_ON") : Localization.localizedString("SETTINGS_STATE_OFF")
        default:
            guard let value = self.profileItem.value else { return "" }
            return String(describing: value)
        }
    }
    
    /// Current profile item value to apply to, and set from, an edit control.
    public var profileItemValue: Any? {
        get {
            return self.profileItem.value
        }
        set {
            self.profileItem.value = newValue
        }
    }
    
    /// The table item should not be editable if the profile item itself is readonly;
    /// otherwise honor this flag's setting, defaulting to false.
    private var _isEditable: Bool?
    public var isEditable: Bool? {
        get {
            return self.profileItem.readonly ? false : self._isEditable ?? false
        }
        set {
            guard self.profileItem.readonly == false else { return }
            self._isEditable = newValue
        }
    }
    
    /// A set of cohorts (data groups) the participant must be in, in order to show this item in its containing profile section.
    public var inCohorts: Set<String>?
    
    /// A set of cohorts (data groups) the participant must not be in, in order to show this item in its containing profile section.
    public var notInCohorts: Set<String>?
    
    /// Profile item profile table items by default edit when selected.
    private var _onSelected: SBAProfileOnSelectedAction? = .editProfileItem
    public var onSelected: SBAProfileOnSelectedAction? {
        get {
            return self._onSelected ?? .editProfileItem
        }
        set {
            self._onSelected = newValue
        }
    }
    
    // MARK: Profile Item Profile Table Item
    
    /// The profile item key for this profile table item. Required.
    /// - warning: Using a key that is not included in the Profile Manager's profileItems is a coding error.
    public let profileItemKey: String
    
    /// The task info identifier for the step to display to the participant when they ask to edit the value
    /// of the profile item. Optional.
    public let editTaskIdentifier: String?
    
    /// The actual profile item for the given profileItemKey.
    public var profileItem: SBAProfileItem {
        get {
            let profileItems = SBABridgeConfiguration.shared.profileManager.profileItems()
            return profileItems[self.profileItemKey]!
        }
        set {
            var profileItems = SBABridgeConfiguration.shared.profileManager.profileItems()
            profileItems[self.profileItemKey]!.value = newValue.value
       }
    }
    
/* TODO: emm 2019-02-06 deal with this for mPower 2 2.1
    func itemDetailFor(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.calendar = Calendar.current
        return formatter.string(from: date)
    }
    
    open func dateAsItemDetail(_ date: Date) -> String {
        guard let format = DateFormatter.dateFormat(fromTemplate: "Mdy", options: 0, locale: Locale.current)
            else { return String(describing: date) }
        return self.itemDetailFor(date, format: format)
    }
    
    open func dateTimeAsItemDetail(_ dateTime: Date) -> String {
        guard let format = DateFormatter.dateFormat(fromTemplate: "yEMdhma", options: 0, locale: Locale.current)
            else { return String(describing: dateTime) }
        return self.itemDetailFor(dateTime, format: format)
    }
    
    open func timeOfDayAsItemDetail(_ timeOfDay: Date) -> String {
        guard let format = DateFormatter.dateFormat(fromTemplate: "hma", options: 0, locale: Locale.current)
            else { return String(describing: timeOfDay) }
        return self.itemDetailFor(timeOfDay, format: format)
    }
    
    public func centimetersToFeetAndInches(_ centimeters: Double) -> (feet: Double, inches: Double) {
        let inches = centimeters / 2.54
        return ((inches / 12.0).rounded(), inches.truncatingRemainder(dividingBy: 12.0))
    }
    
    @objc(hkQuantityheightAsItemDetail:)
    open func heightAsItemDetail(_ height: HKQuantity) -> String {
        let heightInCm = height.doubleValue(for: HKUnit(from: .centimeter)) as NSNumber
        return self.heightAsItemDetail(heightInCm)
    }
    
    open func heightAsItemDetail(_ height: NSNumber) -> String {
        let formatter = LengthFormatter()
        formatter.isForPersonHeightUse = true
        let meters = height.doubleValue / 100.0 // cm -> m
        return formatter.string(fromMeters: meters)
    }
    
    @objc(hkQuantityWeightAsItemDetail:)
    open func weightAsItemDetail(_ weight: HKQuantity) -> String {
        let weightInKg = weight.doubleValue(for: HKUnit(from: .kilogram)) as NSNumber
        return self.weightAsItemDetail(weightInKg)
    }
    
    open func weightAsItemDetail(_ weight: NSNumber) -> String {
        let formatter = MassFormatter()
        formatter.isForPersonMassUse = true
        return formatter.string(fromKilograms: weight.doubleValue)
    }
    
    override open var detail: String? {
        guard let value = profileItem.value else { return "" }
        if let surveyItem = SBASurveyFactory.profileQuestionSurveyItems?.find(withIdentifier: profileItemKey) as? SBAFormStepSurveyItem,
            let choices = surveyItem.items as? [SBAChoice] {
            let selected = (value as? [Any]) ?? [value]
            let textList = selected.map({ (obj) -> String in
                switch surveyItem.surveyItemType {
                case .form(.singleChoice), .form(.multipleChoice),
                     .dataGroups(.singleChoice), .dataGroups(.multipleChoice):
                    return choices.find({ SBAObjectEquality($0.choiceValue, obj) })?.choiceText ?? String(describing: obj)
                case .account(.profile):
                    guard let options = surveyItem.items as? [String],
                            options.count == 1,
                            let option = SBAProfileInfoOption(rawValue: options[0])
                        else { return String(describing: obj) }
                    switch option {
                    case .birthdate:
                        guard let date = obj as? Date else { return String(describing: obj) }
                        return self.dateAsItemDetail(date)
                    case .height:
                        // could reasonably be stored either as an HKQuantity, or as an NSNumber of cm
                        let hkHeight = obj as? HKQuantity
                        if hkHeight != nil {
                            return self.heightAsItemDetail(hkHeight!)
                        }
                        guard let nsHeight = obj as? NSNumber else { return String(describing: obj) }
                        return self.heightAsItemDetail(nsHeight)
                    case .weight:
                        // could reasonably be stored either as an HKQuantity, or as an NSNumber of kg
                        let hkWeight = obj as? HKQuantity
                        if hkWeight != nil {
                            return self.weightAsItemDetail(hkWeight!)
                        }
                        guard let nsWeight = obj as? NSNumber else { return String(describing: obj) }
                        return self.weightAsItemDetail(nsWeight)
                    default:
                        return String(describing: obj)
                    }
                default:
                    return String(describing: obj)
                }
            })
            return Localization.localizedJoin(textList: textList)
        }
        return String(describing: value)
    }
    
    open var answerMapKeys: [String: String]
    
    // MARK: Decoder
    private enum CodingKeys: String, CodingKey {
        case profileItemKey, answerMapKeys
    }
    
    public required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
        
        // HTML profile table items are not editable
        isEditable = false
        
        let container = try decoder.container(keyedBy: CodingKeys.self)
        profileItemKey = try container.decode(String.self, forKey: .profileItemKey)
        answerMapKeys = try container.decodeIfPresent([String: String].self, forKey: .answerMapKeys) ?? [self.profileItemKey: self.profileItemKey]
    }
 */
}

/* TODO: emm 2018-08-19 deal with this for mPower 2 2.1
/// A profile table item that opens a resource (for example, a task defined in JSON) when selected.
public struct SBAResourceProfileTableItem: SBAProfileTableItem, Decodable, RSDResourceTransformer {
    private enum CodingKeys: String, CodingKey {
        case title, detail, isEditable, inCohorts, notInCohorts, onSelected, resource, bundleIdentifier
    }
    
    // MARK: SBAProfileTableItem
    /// Title to show for the table item.
    public var title: String?
    
    /// Detail text to show for the table item.
    public var detail: String?
    
    /// By default resource profile table items are not editable.
    public var isEditable: Bool? = false
    
    /// A set of cohorts (data groups) the participant must be in, in order to show this item in its containing profile section.
    public var inCohorts: Set<String>?
    
    /// A set of cohorts (data groups) the participant must not be in, in order to show this item in its containing profile section.
    public var notInCohorts: Set<String>?
    
    /// Action to perform when the item is selected. The default for HTML items is to show the HTML.
    public var onSelected: SBAProfileOnSelectedAction? = .showHTML
    
    // MARK: Resource Profile Table Item
    
    /// The resource for this item.
    public let resource: String
    
    // MARK: RSDResourceTransformer
    
    /// The bundle identifier for the resource bundle that contains the html.
    public var bundleIdentifier: String?
    
    /// The default bundle from the factory used to decode this object.
    public var factoryBundle: Bundle? = nil
    
    /// `RSDResourceTransformer` uses this to get the URL.
    public var resourceName: String {
        return htmlResource
    }
    
    /// Ignored - required to conform to `RSDResourceTransformer`
    public var classType: String? {
        return nil
    }

}
 */
