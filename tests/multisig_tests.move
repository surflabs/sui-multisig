#[test_only]
module sui_multisig::multisig_tests {
    use std::vector;

    use sui::object;
    use sui::test_scenario;
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;

    use sui_multisig::multisig::{Self, MultisigAccount, ApproveCap};

    const TEST_USER_ALICE: address = @0xA11CE;
    const TEST_USER_BOB: address = @0xB0B;
    const TEST_USER_FACE: address = @0xFACE;

    #[test]
    fun multisig_with_sui() {
        // create a multisig account
        let start = test_scenario::begin(TEST_USER_ALICE);
        let scenario = &mut start;
        {
            let threshold = 2;
            multisig::create_multisig_account(threshold, test_scenario::ctx(scenario));
        };

        // check the approve_cap and add BOB as signer, check the status is activated
        test_scenario::next_tx(scenario, TEST_USER_ALICE);
        {
            let account_ = test_scenario::take_shared<MultisigAccount>(scenario);
            let account = &mut account_;
            assert!(multisig::account_threshold(account) == 2, 1);
            assert!(multisig::account_signers_count(account) == 1, 2);
            assert!(multisig::account_status(account) == 0, 3);

            let multisig_account_id = object::id(account);

            let approve_cap = test_scenario::take_from_sender<ApproveCap>(scenario);
            assert!(multisig::cap_account_id(&approve_cap) == multisig_account_id, 4);
            test_scenario::return_to_sender(scenario, approve_cap);

            multisig::add_signer(account, TEST_USER_BOB, test_scenario::ctx(scenario));
            assert!(multisig::account_signers_count(account) == 2, 5);
            assert!(multisig::account_status(account) == 1, 6);

            test_scenario::return_shared(account_);
        };

        // BOB deposit 10000 mist into multisig account
        test_scenario::next_tx(scenario, TEST_USER_BOB);
        {
            let coin = coin::mint_for_testing<SUI>(10000, test_scenario::ctx(scenario));
            let account_ = test_scenario::take_shared<MultisigAccount>(scenario);
            let account = &mut account_;

            multisig::deposit<SUI>(account, b"0x2::sui::SUI", coin, test_scenario::ctx(scenario));

            let token = multisig::account_token_by_name(account, b"0x2::sui::SUI");
            assert!(coin::value<SUI>(token) == 10000, 7);
            test_scenario::return_shared(account_);
        };

        // ALICE deposit another 20000 mist into multisig account
        test_scenario::next_tx(scenario, TEST_USER_ALICE);
        {
            let coin = coin::mint_for_testing<SUI>(20000, test_scenario::ctx(scenario));
            let account_ = test_scenario::take_shared<MultisigAccount>(scenario);
            let account = &mut account_;

            multisig::deposit<SUI>(account, b"0x2::sui::SUI", coin, test_scenario::ctx(scenario));

            let token = multisig::account_token_by_name(account, b"0x2::sui::SUI");
            assert!(coin::value<SUI>(token) == 30000, 8);
            test_scenario::return_shared(account_);
        };

        // ALICE create a new transaction which will send 1000 mist to FACE
        test_scenario::next_tx(scenario, TEST_USER_ALICE);
        {
            let account_ = test_scenario::take_shared<MultisigAccount>(scenario);
            let account = &mut account_;
            let child_coin = multisig::account_token_by_name<SUI>(account, b"0x2::sui::SUI");
            assert!(coin::value(child_coin) == 30000, 20);

            multisig::create_transaction(account, 1000, TEST_USER_FACE, b"first transaction", b"0x2::sui::SUI", 0, test_scenario::ctx(scenario));

            let transaction = multisig::account_transaction_by_name(account, b"first transaction");
            assert!(multisig::transaction_issuer(transaction) == TEST_USER_ALICE, 9);
            assert!(multisig::transaction_receiver(transaction) == TEST_USER_FACE, 10);
            assert!(multisig::transaction_balance(transaction) == 1000, 11);
            assert!(multisig::transaction_signatures_count(transaction) == 1, 12);
            test_scenario::return_shared(account_);
        };

        // BOB signed the transaction, check the transaction status
        test_scenario::next_tx(scenario, TEST_USER_BOB);
        {
            let account_ = test_scenario::take_shared<MultisigAccount>(scenario);
            let account = &mut account_;

            let approve_cap = test_scenario::take_from_sender<ApproveCap>(scenario);
            multisig::approve_transaction(&approve_cap, account, b"first transaction", test_scenario::ctx(scenario));

            let transaction = multisig::account_transaction_by_name(account, b"first transaction");
            assert!(multisig::transaction_signatures_count(transaction) == 2, 13);

            test_scenario::return_to_sender(scenario, approve_cap);
            test_scenario::return_shared(account_);
        };

        // ALICE execute the transaction, check that the transaction is destroyed
        test_scenario::next_tx(scenario, TEST_USER_ALICE);
        {
            let account_ = test_scenario::take_shared<MultisigAccount>(scenario);
            let account = &mut account_;

            multisig::execute_transaction<SUI>(account, b"first transaction", test_scenario::ctx(scenario));

            test_scenario::return_shared(account_);
        };

        // FACE check the balance that is exactly 1000 mist
        test_scenario::next_tx(scenario, TEST_USER_FACE);
        {
            let coin = test_scenario::take_from_sender<Coin<SUI>>(scenario);

            assert!(coin::value(&coin) == 1000, 14);

            test_scenario::return_to_sender(scenario, coin);
        };

        test_scenario::end(start);
    }

    #[test]
    fun multisig_batch_add_signer() {
        // create a multisig account
        let start = test_scenario::begin(TEST_USER_ALICE);
        let scenario = &mut start;
        {
            let threshold = 5;
            multisig::create_multisig_account(threshold, test_scenario::ctx(scenario));
        };

        // add multiple signers, check the status is activated
        test_scenario::next_tx(scenario, TEST_USER_ALICE);
        {
            let account_ = test_scenario::take_shared<MultisigAccount>(scenario);
            let account = &mut account_;
            assert!(multisig::account_threshold(account) == 5, 1);
            assert!(multisig::account_signers_count(account) == 1, 2);
            assert!(multisig::account_status(account) == 0, 3);

            let multisig_account_id = object::id(account);

            let approve_cap = test_scenario::take_from_sender<ApproveCap>(scenario);
            assert!(multisig::cap_account_id(&approve_cap) == multisig_account_id, 4);
            test_scenario::return_to_sender(scenario, approve_cap);

            let signers = vector::empty<address>();
            vector::push_back(&mut signers, @0x11);
            vector::push_back(&mut signers, @0x22);
            vector::push_back(&mut signers, @0x33);
            vector::push_back(&mut signers, @0x44);
            vector::push_back(&mut signers, @0x55);

            multisig::batch_add_signer(account, signers, test_scenario::ctx(scenario));
            assert!(multisig::account_signers_count(account) == 6, 5);
            assert!(multisig::account_status(account) == 1, 6);

            test_scenario::return_shared(account_);
        };

        test_scenario::end(start);
    }
}