//
//  SBAFactory.swift
//  BridgeApp
//
//  Copyright © 2018 Sage Bionetworks. All rights reserved.
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
import BridgeSDK
import Research

/// The category type of an object. This is used to decide which decode*(from:) method to call to
/// decode the item.
public struct SBACategoryType : RawRepresentable, Codable {
    public typealias RawValue = String
    
    public private(set) var rawValue: String
    
    public init(rawValue: String) {
        self.rawValue = rawValue
    }
    
    /// Defaults to decoding a task object.
    public static let task: SBACategoryType = "task"
    
    /// Defaults to decoding a profile manager object.
    public static let profileManager: SBACategoryType = "profileManager"
    
    /// Defaults to decoding a profile data source object.
    public static let profileDataSource: SBACategoryType = "profileDataSource"
    
    /// List of all the standard types.
    public static func allStandardTypes() -> [SBACategoryType] {
        return [.task, .profileManager, .profileDataSource]
    }
}

extension SBACategoryType : Equatable {
    public static func ==(lhs: SBACategoryType, rhs: SBACategoryType) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    public static func ==(lhs: String, rhs: SBACategoryType) -> Bool {
        return lhs == rhs.rawValue
    }
    public static func ==(lhs: SBACategoryType, rhs: String) -> Bool {
        return lhs.rawValue == rhs
    }
}

extension SBACategoryType : Hashable {
    public var hashValue : Int {
        return self.rawValue.hashValue
    }
}

extension SBACategoryType : ExpressibleByStringLiteral {
    public typealias StringLiteralType = String
    
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }
}

extension SBACategoryType {
    static func allCodingKeys() -> [String] {
        return allStandardTypes().map{ $0.rawValue }
    }
}

open class SBAFactory : RSDFactory {
    
    public var configuration : SBABridgeConfiguration {
        return SBABridgeConfiguration.shared
    }
    
    // MARK: Class category factory
    
    private enum CatTypeKeys: String, CodingKey {
        case catType
    }
    
    /// Get a string that will identify the category of object to instantiate for the given decoder.
    ///
    /// By default, this will look in the container for the decoder for a key/value pair where
    /// the key == "catType" and the value is a `String`.
    ///
    /// - parameter decoder: The decoder to inspect.
    /// - returns: The string representing this category type (if found).
    /// - throws: `DecodingError` if the category name cannot be decoded.
    open func catTypeName(from decoder:Decoder) throws -> String {
        let container = try decoder.container(keyedBy: CatTypeKeys.self)
        // Return the task as the default catType syoung 07/26/2019
        return try container.decodeIfPresent(String.self, forKey: .catType) ?? SBACategoryType.task.rawValue
    }
    
    /// Decode an object. This will check the category type to decide which decode* method to call.
    open func decodeObject(from decoder: Decoder) throws -> (SBACategoryType, Any) {
        let catTypeName = try self.catTypeName(from: decoder)
        let catType: SBACategoryType = SBACategoryType(rawValue: catTypeName)
        switch catType {
        case .task:
            return (catType, try self.decodePolymorphicObject(RSDTask.self, from: decoder))
        case .profileManager:
            return (catType, try self.decodeProfileManager(from: decoder))
        case .profileDataSource:
            return (catType, try self.decodeProfileDataSource(from: decoder))
        default:
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "\(self) does not support `\(catTypeName)` as a decodable category type.")
            throw DecodingError.typeMismatch(SBACategoryType.self, context)
        }
    }
    
    open func decodeProfileManager(from decoder: Decoder) throws -> SBAProfileManager {
        let typeName: String = try decoder.factory.typeName(from: decoder) ?? SBAProfileManagerType.profileManager.rawValue
        let type = SBAProfileManagerType(rawValue: typeName)
        switch type {
        case .profileManager:
            return try SBAProfileManagerObject(from: decoder)
        default:
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "\(self) does not support `\(typeName)` as a decodable profile manager type.")
            throw DecodingError.typeMismatch(SBAProfileManagerType.self, context)
        }
    }
    
    open func decodeProfileDataSource(from decoder: Decoder) throws -> SBAProfileDataSource {
        let typeName: String = try decoder.factory.typeName(from: decoder) ?? SBAProfileDataSourceType.profileDataSource.rawValue
        let type = SBAProfileDataSourceType(rawValue: typeName)
        switch type {
        case .profileDataSource:
            return try SBAProfileDataSourceObject(from: decoder)
        default:
            let context = DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "\(self) does not support `\(typeName)` as a decodable profile data source type.")
            throw DecodingError.typeMismatch(SBAProfileDataSourceType.self, context)
        }
    }
}
