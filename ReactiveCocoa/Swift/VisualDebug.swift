//
//  VisualDebug.swift
//  ReactiveCocoa
//
//  Created by Sergey gavrilyuk on 2016-06-19.
//  Copyright © 2016 GitHub. All rights reserved.
//

import Foundation

//struct UUID {
//	private let storage: [UInt32]
//	init() {
//		self.storage = (0..<16).map { _ in arc4random() }
//	}
//}
//
//extension UUID: Hashable {
//	var hashValue: Int {
//		return self.storage[0].hashValue ^ self.storage[1].hashValue
//	}
//}
//
//func ==(lhs: UUID, rhs: UUID) -> Bool {
//	return lhs.storage == rhs.storage
//}
//


struct UUID {
	static var count: Int = 0
	
	private let number: Int
	init() {
		self.number = UUID.count
		UUID.count += 1
	}
}

extension UUID: Hashable {
	var hashValue: Int {
		return self.number.hashValue
	}
}

func ==(lhs: UUID, rhs: UUID) -> Bool {
	return lhs.number == rhs.number
}


extension UUID: CustomDebugStringConvertible {
	var debugDescription: String {
		return "\(self.number)"
	}
}


//struct Witness {
//	
//	let failed: ErrorType -> ()
//	let completed: () -> ()
//	let interrupted: () -> ()
//	let next: Any -> ()
//	
//	init(failed: ErrorType -> (), completed:() -> (), interrupted: () -> (), next: Any -> ()) {
//		self.failed = failed
//		self.completed = completed
//		self.interrupted = interrupted
//		self.next = next
//	}
//}




protocol WitnessedObserverType {
	var valueType: Any.Type { get }
	var errorType: ErrorType.Type { get }
	
}


struct WitnessedNode {
	let uuid: UUID
	let valueType: Any.Type
	let errorType: ErrorType.Type
	
	init(observer: WitnessedObserverType) {
		self.uuid = UUID()
		self.valueType = observer.valueType
		self.errorType = observer.errorType
	}
}



enum VisualDebugEvent {
	case failed(ErrorType)
	case interrupted
	case completed
	case next(Any)
}



final class ViualDebugHelper {
	
	static let sharedInstance = ViualDebugHelper()
	
	private let observersRegistry: [WitnessedNode] = []
	let queue: dispatch_queue_t = dispatch_queue_create("com.rac.visualdebug", nil)
	
	func handleEventSerialized(observerUuid: UUID, event: VisualDebugEvent) {
		dispatch_async(self.queue) {
			self.showEvent(observerUuid, event: event)
		}
	}
	
	func showEvent(observerUuid: UUID, event: VisualDebugEvent) {
		switch event {
		case .next(let value as CustomDebugStringConvertible):
			print("observer \(observerUuid.debugDescription) recevied `next` event with value \(value.debugDescription)")
		case .next(_):
			print("observer \(observerUuid.debugDescription) received `next` event but can't show value")
		default:()
		}
	}
	
	func witnessObserver<V, E: ErrorType>(observer: Observer<V,E>) -> Observer<V,E> {
		let node = WitnessedNode(observer: observer)
		let uuid = node.uuid
		
		let witness = {[unowned self](event: VisualDebugEvent) in
			self.handleEventSerialized(uuid, event: event)
		}
		
		return Observer<V,E> { event in
			switch event {
			case .Completed:			witness(.completed)
			case .Failed(let error):	witness(.failed(error))
			case .Interrupted:			witness(.interrupted)
			case .Next(let value):		witness(.next(value))
			}
			observer.action(event)
		}
		
	}
}





extension Observer: WitnessedObserverType {
	var valueType: Any.Type { return Value.self }
	var errorType: ErrorType.Type { return Error.self }
	
	mutating func witness(witness: VisualDebugEvent -> ()) {
		let oldAction = self.action
		self.action = { event in
			
			oldAction(event)
		}
	}
}


