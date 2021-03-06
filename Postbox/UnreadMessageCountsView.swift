import Foundation

public enum UnreadMessageCountsItem: Equatable {
    case total(ValueBoxKey?)
    case peer(PeerId)
    case group(PeerGroupId)
}

private enum MutableUnreadMessageCountsItemEntry {
    case total((ValueBoxKey, PreferencesEntry?)?, ChatListTotalUnreadState)
    case peer(PeerId, CombinedPeerReadState?)
    case group(PeerGroupId, ChatListGroupReferenceUnreadCounters)
}

public enum UnreadMessageCountsItemEntry {
    case total(PreferencesEntry?, ChatListTotalUnreadState)
    case peer(PeerId, CombinedPeerReadState?)
    case group(PeerGroupId, Int32)
}

final class MutableUnreadMessageCountsView: MutablePostboxView {
    fileprivate var entries: [MutableUnreadMessageCountsItemEntry]
    
    init(postbox: Postbox, items: [UnreadMessageCountsItem]) {
        self.entries = items.map { item in
            switch item {
                case let .total(preferencesKey):
                    return .total(preferencesKey.flatMap({ ($0, postbox.preferencesTable.get(key: $0)) }), postbox.messageHistoryMetadataTable.getChatListTotalUnreadState())
                case let .peer(peerId):
                    return .peer(peerId, postbox.readStateTable.getCombinedState(peerId))
                case let .group(groupId):
                    return .group(groupId, ChatListGroupReferenceUnreadCounters(postbox: postbox, groupId: groupId))
            }
        }
    }
    
    func replay(postbox: Postbox, transaction: PostboxTransaction) -> Bool {
        var updated = false
        
        var updatedPreferencesEntry: PreferencesEntry?
        if !transaction.currentPreferencesOperations.isEmpty {
            for i in 0 ..< self.entries.count {
                if case let .total(maybeKeyAndValue, _) = self.entries[i], let (key, _) = maybeKeyAndValue {
                    for operation in transaction.currentPreferencesOperations {
                        if case let .update(updateKey, value) = operation {
                            if key == updateKey {
                                updatedPreferencesEntry = value
                            }
                        }
                    }
                }
            }
        }
        
        if transaction.currentUpdatedTotalUnreadState != nil || !transaction.alteredInitialPeerCombinedReadStates.isEmpty || updatedPreferencesEntry != nil {
            for i in 0 ..< self.entries.count {
                switch self.entries[i] {
                    case let .total(keyAndEntry, state):
                        if transaction.currentUpdatedTotalUnreadState != nil {
                            let updatedState = postbox.messageHistoryMetadataTable.getChatListTotalUnreadState()
                            if updatedState != state {
                                self.entries[i] = .total(keyAndEntry.flatMap({ ($0.0, updatedPreferencesEntry ?? $0.1) }), updatedState)
                                updated = true
                            }
                        }
                    case let .peer(peerId, _):
                        if transaction.alteredInitialPeerCombinedReadStates[peerId] != nil {
                            self.entries[i] = .peer(peerId, postbox.readStateTable.getCombinedState(peerId))
                            updated = true
                        }
                    case let .group(_, counters):
                        if counters.replay(postbox: postbox, transaction: transaction) {
                            updated = true
                        }
                }
            }
        }
        
        return updated
    }
    
    func immutableView() -> PostboxView {
        return UnreadMessageCountsView(self)
    }
}

public final class UnreadMessageCountsView: PostboxView {
    public let entries: [UnreadMessageCountsItemEntry]
    
    init(_ view: MutableUnreadMessageCountsView) {
        self.entries = view.entries.map { entry in
            switch entry {
                case let .total(keyAndValue, state):
                    return .total(keyAndValue?.1, state)
                case let .peer(peerId, count):
                    return .peer(peerId, count)
                case let .group(groupId, counters):
                    let (unread, mutedUnread) = counters.getCounters()
                    return .group(groupId, unread + mutedUnread)
            }
        }
    }
    
    public func total() -> (PreferencesEntry?, ChatListTotalUnreadState)? {
        for entry in self.entries {
            switch entry {
                case let .total(preferencesEntry, state):
                    return (preferencesEntry, state)
                default:
                    break
            }
        }
        return nil
    }
    
    public func count(for item: UnreadMessageCountsItem) -> Int32? {
        for entry in self.entries {
            switch entry {
                case .total:
                    break
                case let .peer(peerId, state):
                    if case .peer(peerId) = item {
                        return state?.count ?? 0
                    }
                case let .group(groupId, count):
                    if case .group(groupId) = item {
                        return count
                    }
            }
        }
        return nil
    }
}
