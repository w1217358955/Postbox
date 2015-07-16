import UIKit
import XCTest

import Postbox

class TestParent: Coding, Equatable {
    var parentInt32: Int32
    
    required init(decoder: Decoder) {
        self.parentInt32 = decoder.decodeInt32ForKey("parentInt32")
    }
    
    init(parentInt32: Int32) {
        self.parentInt32 = parentInt32
    }
    
    func encode(encoder: Encoder) {
        encoder.encodeInt32(self.parentInt32, forKey: "parentInt32")
    }
}

class TestObject: TestParent {
    var int32: Int32
    var int64: Int64
    var double: Double
    var string: String
    var int32Array: [Int32]
    var int64Array: [Int64]
    
    required init(decoder: Decoder) {
        self.int32 = decoder.decodeInt32ForKey("int32")
        self.int64 = decoder.decodeInt64ForKey("int64")
        self.double = decoder.decodeDoubleForKey("double")
        self.string = decoder.decodeStringForKey("string")
        self.int32Array = decoder.decodeInt32ArrayForKey("int32Array")
        self.int64Array = decoder.decodeInt64ArrayForKey("int64Array")
        super.init(decoder: decoder)
    }
    
    init(parentInt32: Int32, int32: Int32, int64: Int64, double: Double, string: String, int32Array: [Int32], int64Array: [Int64]) {
        self.int32 = int32
        self.int64 = int64
        self.double = double
        self.string = string
        self.int32Array = int32Array
        self.int64Array = int64Array
        super.init(parentInt32: parentInt32)
    }
    
    override func encode(encoder: Encoder) {
        encoder.encodeInt32(self.int32, forKey: "int32")
        encoder.encodeInt64(self.int64, forKey: "int64")
        encoder.encodeDouble(self.double, forKey: "double")
        encoder.encodeString(self.string, forKey: "string")
        encoder.encodeInt32Array(self.int32Array, forKey: "int32Array")
        encoder.encodeInt64Array(self.int64Array, forKey: "int64Array")
        super.encode(encoder)
    }
}

class TestKey: Coding, Hashable {
    let value: Int
    required init(decoder: Decoder) {
        self.value = Int(decoder.decodeInt32ForKey("value"))
    }
    
    init(value: Int) {
        self.value = value
    }
    
    func encode(encoder: Encoder) {
        encoder.encodeInt32(Int32(self.value), forKey: "value")
    }
    
    var hashValue: Int {
        get {
            return self.value
        }
    }
}

func ==(lhs: TestObject, rhs: TestObject) -> Bool {
    return lhs.int32 == rhs.int32 &&
        lhs.int64 == rhs.int64 &&
        lhs.double == rhs.double &&
        lhs.string == rhs.string &&
        lhs.int32Array == rhs.int32Array &&
        lhs.int64Array == rhs.int64Array &&
        lhs.parentInt32 == rhs.parentInt32
}

func ==(lhs: TestParent, rhs: TestParent) -> Bool {
    return lhs.parentInt32 == rhs.parentInt32
}

func ==(lhs: TestKey, rhs: TestKey) -> Bool {
    return lhs.value == rhs.value
}

class SerializationTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testExample() {
        declareEncodable(TestParent.self, { TestParent(decoder: $0) })
        declareEncodable(TestObject.self, { TestObject(decoder: $0) })
        declareEncodable(TestKey.self, { TestKey(decoder: $0) })
        
        let encoder = Encoder()
        encoder.encodeInt32(12345, forKey: "a")
        encoder.encodeInt64(Int64(12345), forKey: "b")
        encoder.encodeBool(true, forKey: "c")
        encoder.encodeString("test", forKey: "d")
        
        let before = TestObject(parentInt32: 100, int32: 12345, int64: 67890, double: 1.23456, string: "test", int32Array: [1, 2, 3, 4, 5], int64Array: [6, 7, 8, 9, 0])
        encoder.encodeObject(before, forKey: "e")
        
        encoder.encodeInt32Array([1, 2, 3, 4], forKey: "f")
        encoder.encodeInt64Array([1, 2, 3, 4], forKey: "g")
        
        let beforeArray: [TestParent] = [TestObject(parentInt32: 1000, int32: 12345, int64: 67890, double: 1.23456, string: "test", int32Array: [1, 2, 3, 4, 5], int64Array: [6, 7, 8, 9, 0]), TestParent(parentInt32: 2000)]
        
        encoder.encodeObjectArray(beforeArray, forKey: "h")
        
        let beforeDictionary: [TestKey : TestParent] = [
            TestKey(value: 1): TestObject(parentInt32: 1000, int32: 12345, int64: 67890, double: 1.23456, string: "test", int32Array: [1, 2, 3, 4, 5], int64Array: [6, 7, 8, 9, 0]),
            TestKey(value: 2): TestParent(parentInt32: 2000)
        ]
        
        encoder.encodeObjectDictionary(beforeDictionary, forKey: "i")
        
        let decoder = Decoder(buffer: encoder.makeReadBufferAndReset())
        
        let afterDictionary = decoder.decodeObjectDictionaryForKey("i") as [TestKey : TestParent]
        XCTAssert(afterDictionary == beforeDictionary, "object dictionary failed")
        
        let afterArray = decoder.decodeObjectArrayForKey("h") as [TestParent]
        XCTAssert(afterArray == beforeArray, "object array failed")
        
        XCTAssert(decoder.decodeInt64ArrayForKey("g") == [1, 2, 3, 4], "int64 array failed")
        XCTAssert(decoder.decodeInt32ArrayForKey("f") == [1, 2, 3, 4], "int32 array failed")
        
        if let after = decoder.decodeObjectForKey("e") as? TestObject {
            XCTAssert(after == before, "object failed")
        } else {
            XCTFail("object failed")
        }
        
        XCTAssert(decoder.decodeStringForKey("d") == "test", "string failed")
        XCTAssert(decoder.decodeBoolForKey("c"), "bool failed")
        XCTAssert(decoder.decodeInt64ForKey("b") == Int64(12345), "int64 failed")
        XCTAssert(decoder.decodeInt32ForKey("a") == 12345, "int32 failed")
    }
}