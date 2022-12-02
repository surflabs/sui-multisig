module sui_multisig::multisig {
    use std::vector;
    use std::string::{Self, String};

    use sui::object::{Self, ID, UID};
    use sui::transfer;
    use sui::event;
    use sui::tx_context::{Self, TxContext};
    use sui::coin::{Self, Coin};
    use sui::object_bag::{Self, ObjectBag};
    use sui::object_table::{Self, ObjectTable};

    // Status constants
    const Inactivated: u8 = 0;
    const Activated: u8 = 1;

    // ErrorCode
    // The threshold should at least be greater than 2
    const EInvalidThreshold: u64 = 1;
    // Already is signer
    const EAlreadySigner: u64 = 2;
    // Only the multisig account' creator can add signer
    const EInvalidCreator: u64 = 3;
    const EInvalidSigner: u64 = 4;
    const ENotEnoughSigners: u64 = 5;
    const EAlreadyBanned: u64 = 6;
    const EInvalidBannedSigner: u64 = 7;
    const EInvalidApproveCap: u64 = 8;
    const EBeyondEpoch: u64 = 9;
    const EInvalidEpoch: u64 = 10;
    const EInvalidCoin: u64 = 11;
    const EInvalidIssuer: u64 = 12;
    const EAlreadyApproved: u64 = 13;
    const EAlreadyExistedTransaction: u64 = 14;

    struct MultisigAccount has key, store {
        id: UID,
        signers: vector<address>,
        banned: vector<address>,
        threshold: u8,
        status: u8,
        creator: address,
        tokens: ObjectBag,
        txs: ObjectTable<String, Transaction>,
    }

    struct Transaction has key, store {
        id: UID,
        balance: u64,
        issuer: address,
        receiver: address,
        locked_before: u64,
        signatures: vector<Signature>,
        transaction_name: String,
        token_name: String,
        multisig_id: ID,
    }

    struct Signature has store, copy, drop {
        signer: address,
        epoch: u64,
    }

    struct ApproveCap has key {
        id: UID,
        multisig_account_id: ID,
    }

    struct CreateMultisigEvent has copy, drop {
        account_id: ID,
        creator: address,
    }

    struct AddApproverEvent has copy, drop {
        account_id: ID,
        signer: address,
    }

    struct BanApproverEvent has copy, drop {
        account_id: ID,
        signer: address,
    }

    struct ThawBannedApproverEvent has copy, drop {
        account_id: ID,
        signer: address,
    }

    struct ModifyThresholdEvent has copy, drop {
        account_id: ID,
        new_threshold: u8,
    }

    struct DepositEvent<phantom T> has copy, drop {
        account_id: ID,
        depositier: address,
        amount: u64,  // Coin<T>,
    }

    struct CreateTransactionEvent has copy, drop {
        account_id: ID,
        transaction_id: ID,
        issuer: address,
        balance: u64,
        receiver: address,
    }

    struct ApproveEvent has copy, drop {
        account_id: ID,
        transaction_id: ID,
        signer: address,
    }

    struct ExecuteTransactionEvent has copy, drop {
        account_id: ID,
        transaction_id: ID,
        executor: address,
    }

    struct CancelTransactionEvent has copy, drop {
        account_id: ID,
        transaction_id: ID,
    }

    /// Getter functions
    public fun account_threshold(account: &MultisigAccount): u8 { account.threshold }
    public fun account_signers_count(account: &MultisigAccount): u64 { vector::length(&account.signers) - vector::length(&account.banned) }
    public fun account_status(account: &MultisigAccount): u8 { account.status }

    #[test_only]
    public fun account_token_by_name<T>(account: &MultisigAccount, name: vector<u8>): &Coin<T> {
        object_bag::borrow<String, Coin<T>>(
            &account.tokens,
            string::utf8(name),
        )
    }
    #[test_only]
    public fun account_transaction_by_name(
        account: &MultisigAccount,
        tx_name: vector<u8>,
    ): &Transaction {
        object_table::borrow(
            &account.txs,
            string::utf8(tx_name),
        )
    }

    public fun cap_account_id(cap: &ApproveCap): ID { cap.multisig_account_id }

    public fun transaction_balance(transaction: &Transaction): u64 { transaction.balance }
    public fun transaction_issuer(transaction: &Transaction): address { transaction.issuer }
    public fun transaction_receiver(transaction: &Transaction): address { transaction.receiver }
    public fun transaction_signatures_count(transaction: &Transaction): u64 {
        vector::length(&transaction.signatures)
    }


    /// Helper functions
    fun transfer_approve_cap(account_id: ID, owner: address, ctx: &mut TxContext) {
        transfer::transfer(ApproveCap {
            id: object::new(ctx),
            multisig_account_id: account_id,
        }, owner);
    }
    fun check_creator(multisig_account: &MultisigAccount, ctx: &TxContext) {
        assert!(multisig_account.creator == tx_context::sender(ctx), EInvalidCreator);
    }
    fun check_signer(multisig_account: &MultisigAccount, ctx: &mut TxContext) {
        assert!(vector::contains(&multisig_account.signers, &tx_context::sender(ctx)), EInvalidSigner);
        assert!(!vector::contains(&multisig_account.banned, &tx_context::sender(ctx)), EAlreadyBanned);
    }
    fun borrow_signer(signature: &Signature): &address {
        &signature.signer
    }
    fun check_account(multisig_account: &MultisigAccount) {
        assert!(multisig_account.status == Activated, ENotEnoughSigners);
    }
    fun check_approve_cap(cap: &ApproveCap, account: &MultisigAccount) {
        assert!(cap_account_id(cap) == object::id(account), EInvalidApproveCap);
    }
    fun check_locked_time(tx: &Transaction, ctx: &TxContext) {
        if (tx.locked_before != 0) {
            assert!(tx.locked_before <= tx_context::epoch(ctx), EBeyondEpoch);
        }
    }
    fun check_issuer(tx: &Transaction, ctx: &TxContext) {
        assert!(transaction_issuer(tx) == tx_context::sender(ctx), EInvalidIssuer);
    }


    /// Admin functions
    public entry fun create_multisig_account(threshold: u8, ctx: &mut TxContext) {
        let id = object::new(ctx);
        let account_id = object::uid_to_inner(&id);
        let sender = tx_context::sender(ctx);

        assert!(threshold > 1, EInvalidThreshold);
    
        let account = MultisigAccount {
            id,
            signers: vector[sender],
            banned: vector::empty(),
            threshold,
            status: Inactivated,
            creator: sender,
            tokens: object_bag::new(ctx),
            txs: object_table::new<String, Transaction>(ctx),
        };
        transfer::share_object(account);

        transfer_approve_cap(account_id, sender, ctx);

        event::emit(CreateMultisigEvent {
            account_id,
            creator: sender,
        });
    }

    public entry fun add_signer(
        multisig_account: &mut MultisigAccount,
        new_signer: address,
        ctx: &mut TxContext,
    ) {
        assert!(!vector::contains(&multisig_account.signers, &new_signer), EAlreadySigner);

        check_creator(multisig_account, ctx);

        vector::push_back(&mut multisig_account.signers, new_signer);

        if (account_signers_count(multisig_account) >= (multisig_account.threshold as u64)) {
            multisig_account.status = Activated
        };
        let account_id = object::id(multisig_account);

        transfer_approve_cap(account_id, new_signer, ctx);

        event::emit(AddApproverEvent {
            account_id,
            signer: new_signer,
        });
    }

    public entry fun batch_add_signer(multisig_account: &mut MultisigAccount, signers: vector<address>, ctx: &mut TxContext) {
        let signer_len = vector::length(&signers);
        let i = 0;
        while (i < signer_len) {
            add_signer(multisig_account, *vector::borrow(&signers, i), ctx);
            i = i + 1;
        }
    }

    public entry fun ban_signer(multisig_account: &mut MultisigAccount, signer: address, ctx: &mut TxContext) {
        check_creator(multisig_account, ctx);

        assert!(vector::contains(&multisig_account.signers, &signer), EInvalidSigner);
        assert!(!vector::contains(&multisig_account.banned, &signer), EAlreadyBanned);

        vector::push_back(&mut multisig_account.banned, signer);

        let valid_signers_count = account_signers_count(multisig_account);
        if (valid_signers_count < (multisig_account.threshold as u64)) {
            multisig_account.status = Inactivated
        };

        event::emit(BanApproverEvent {
            account_id: object::id(multisig_account),
            signer: tx_context::sender(ctx),
        });
    }

    public entry fun thaw_banned_signer(multisig_account: &mut MultisigAccount, signer: address, ctx: &mut TxContext) {
        check_creator(multisig_account, ctx);

        assert!(vector::contains(&multisig_account.signers, &signer), EInvalidSigner);
        assert!(vector::contains(&multisig_account.banned, &signer), EInvalidBannedSigner);

        let (_, index) = vector::index_of(&multisig_account.banned, &signer);
        vector::remove(&mut multisig_account.banned, index);

        let valid_signers_count = account_signers_count(multisig_account);
        if (valid_signers_count >= (multisig_account.threshold as u64)) {
            multisig_account.status = Activated
        };

        event::emit(ThawBannedApproverEvent {
            account_id: object::id(multisig_account),
            signer: tx_context::sender(ctx),
        });
    }

    public entry fun modify_threshold(multisig_account: &mut MultisigAccount, new_threshold: u8, ctx: &mut TxContext) {
        check_creator(multisig_account, ctx);
        assert!(new_threshold > 1, EInvalidThreshold);

        multisig_account.threshold = new_threshold;
        let valid_signers_count = account_signers_count(multisig_account);
        if (valid_signers_count >= (new_threshold as u64)) {
            multisig_account.status = Activated
        } else if (valid_signers_count < (new_threshold as u64)) {
            multisig_account.status = Inactivated
        };

        event::emit(ModifyThresholdEvent {
            account_id: object::id(multisig_account),
            new_threshold,
        });
    }


    /// General functions
    public entry fun deposit<T>(
        multisig_account: &mut MultisigAccount,
        name: vector<u8>,
        coin: Coin<T>,
        ctx: &mut TxContext,
    ) {
        check_signer(multisig_account, ctx);

        let value = coin::value(&coin);

        let token_name = string::utf8(name);

        if (!object_bag::contains<String>(&multisig_account.tokens, token_name)) {
            object_bag::add<String, Coin<T>>(
                &mut multisig_account.tokens,
                token_name,
                coin,
            )
        } else {
            coin::join<T>(
                object_bag::borrow_mut<String, Coin<T>>(
                    &mut multisig_account.tokens,
                    token_name,
                ),
                coin,
            )
        };

        event::emit(DepositEvent<T> {
            account_id: object::id(multisig_account),
            depositier: tx_context::sender(ctx),
            amount: value,
        });
    }

    public entry fun create_transaction(
        multisig_account: &mut MultisigAccount,
        balance: u64,
        receiver: address,
        transaction_name: vector<u8>,
        token_name: vector<u8>,
        locked_before: u64,
        ctx: &mut TxContext,
    ) {
        check_signer(multisig_account, ctx);
        check_account(multisig_account);

        if (locked_before != 0) {
            assert!(locked_before >= tx_context::epoch(ctx), EInvalidEpoch);
        };
        
        let sender = tx_context::sender(ctx);
        let id = object::new(ctx);
        let transaction_id = object::uid_to_inner(&id);
        let transaction_name = string::utf8(transaction_name);
        let tx = Transaction {
            id,
            balance,
            issuer: sender,
            receiver,
            locked_before,
            signatures: vector[Signature { signer: sender, epoch: tx_context::epoch(ctx) }],
            transaction_name,
            token_name: string::utf8(token_name),
            multisig_id: object::id(multisig_account),
        };

        assert!(!object_table::contains<String, Transaction>(&multisig_account.txs, transaction_name), EAlreadyExistedTransaction);
        object_table::add<String, Transaction>(
            &mut multisig_account.txs,
            transaction_name,
            tx,
        );

        event::emit(CreateTransactionEvent {
            account_id: object::id(multisig_account),
            transaction_id,
            balance,
            issuer: sender,
            receiver,
        });
    }

    public entry fun approve_transaction(
        cap: &ApproveCap,
        multisig_account: &mut MultisigAccount,
        transaction_name: vector<u8>,
        ctx: &mut TxContext,
    ) {
        check_signer(multisig_account, ctx);
        check_approve_cap(cap, multisig_account);

        let transaction = object_table::borrow_mut<String, Transaction>(
            &mut multisig_account.txs,
            string::utf8(transaction_name),
        );
        let transaction_id = object::id(transaction);
        check_locked_time(transaction, ctx);

        let sender = tx_context::sender(ctx);
        let i = 0;
        let length = vector::length(&transaction.signatures);
        while (i < length) {
            if (borrow_signer(vector::borrow(&transaction.signatures, i)) == &sender) {
                return
            };
            i = i + 1;
        };

        vector::push_back(&mut transaction.signatures, Signature {
            signer: sender,
            epoch: tx_context::epoch(ctx),
        });

        event::emit(ApproveEvent {
            account_id: object::id(multisig_account),
            transaction_id,
            signer: sender,
        });
    }

    public entry fun execute_transaction<T>(
        multisig_account: &mut MultisigAccount,
        transaction_name: vector<u8>,
        ctx: &mut TxContext,
    ) {
        check_signer(multisig_account, ctx);

        let transaction = object_table::remove<String, Transaction>(
            &mut multisig_account.txs,
            string::utf8(transaction_name),
        );
        let signers = vector::length(&transaction.signatures);
        let threshold = multisig_account.threshold;
        assert!(signers >= (threshold as u64), ENotEnoughSigners);
    
        let Transaction {
            id,
            balance,
            issuer: _,
            receiver,
            locked_before: _,
            signatures: _,
            transaction_name: _,
            token_name,
            multisig_id,
        } = transaction;

        assert!(object_bag::contains<String>(&multisig_account.tokens, token_name), EInvalidCoin);
        let coin = object_bag::borrow_mut<String, Coin<T>>(&mut multisig_account.tokens, token_name);

        transfer::transfer(coin::take(coin::balance_mut(coin), balance, ctx), receiver);
        event::emit(ExecuteTransactionEvent {
            account_id: multisig_id,
            transaction_id: object::uid_to_inner(&id),
            executor: tx_context::sender(ctx),
        });

        object::delete(id);
    }

    public entry fun cancel_transaction(
        multisig_account: &mut MultisigAccount,
        transaction_name: vector<u8>,
        ctx: &mut TxContext,
    ) {
        let transaction = object_table::remove<String, Transaction>(
            &mut multisig_account.txs,
            string::utf8(transaction_name),
        );
        check_issuer(&transaction, ctx);

        let signers = vector::length(&transaction.signatures);
        let threshold = multisig_account.threshold;
        assert!(signers < (threshold as u64), EAlreadyApproved);

        let Transaction {
            id,
            balance: _,
            issuer: _,
            receiver: _,
            locked_before: _,
            signatures: _,
            transaction_name: _,
            token_name: _,
            multisig_id,
        } = transaction;

        event::emit(CancelTransactionEvent {
            account_id: multisig_id,
            transaction_id: object::uid_to_inner(&id),
        });
        
        object::delete(id);
    }
}
