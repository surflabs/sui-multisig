import { 
  RawSigner, 
  SuiExecuteTransactionResponse, 
  SuiAddress, 
  ObjectId 
} from '@mysten/sui.js';

export async function createMultisigAccount(
  signer: RawSigner, 
  threshold: number, 
  contract: SuiAddress,
): Promise<SuiExecuteTransactionResponse> {
  return await signer.executeMoveCall({
    packageObjectId: contract,
    module: 'sui_multisig',
    function: 'create_multisig_account',
    typeArguments: [],
    arguments: [
      threshold
    ],
    gasBudget: 1000,
  });
}

export async function addSigner(
  signer: RawSigner, 
  multisigAccount: ObjectId, 
  newSigner: SuiAddress, 
  contract: SuiAddress,
): Promise<SuiExecuteTransactionResponse> {
  return await signer.executeMoveCall({
    packageObjectId: contract,
    module: 'sui_multisig',
    function: 'add_signer',
    typeArguments: [],
    arguments: [
      multisigAccount,
      newSigner
    ],
    gasBudget: 1000,
  })
}

export async function batchAddSigner(
  signer: RawSigner,
  multisigAccount: ObjectId,
  newSigners: Array<SuiAddress>,
  contract: SuiAddress,
): Promise<SuiExecuteTransactionResponse> {
  return await signer.executeMoveCall({
    packageObjectId: contract,
    module: 'sui_multisig',
    function: 'batch_add_signer',
    typeArguments: [],
    arguments: [
      multisigAccount,
      newSigners
    ],
    gasBudget: 1000,
  })
}

export async function banSigner(
  signer: RawSigner, 
  multisigAccount: ObjectId, 
  newSigner: SuiAddress, 
  contract: SuiAddress,
): Promise<SuiExecuteTransactionResponse> {
  return await signer.executeMoveCall({
    packageObjectId: contract,
    module: 'sui_multisig',
    function: 'ban_signer',
    typeArguments: [],
    arguments: [
      multisigAccount,
      newSigner
    ],
    gasBudget: 1000,
  })
}

export async function thawBannedSigner(
  signer: RawSigner, 
  multisigAccount: ObjectId, 
  newSigner: SuiAddress, 
  contract: SuiAddress,
): Promise<SuiExecuteTransactionResponse> {
  return await signer.executeMoveCall({
    packageObjectId: contract,
    module: 'sui_multisig',
    function: 'thaw_banned_signer',
    typeArguments: [],
    arguments: [
      multisigAccount,
      newSigner
    ],
    gasBudget: 1000,
  })
}

export async function modifyThreshold(
  signer: RawSigner, 
  multisigAccount: ObjectId, 
  newThreshold: number, 
  contract: SuiAddress,
): Promise<SuiExecuteTransactionResponse> {
  return await signer.executeMoveCall({
    packageObjectId: contract,
    module: 'sui_multisig',
    function: 'modify_threshold',
    typeArguments: [],
    arguments: [
      multisigAccount,
      newThreshold
    ],
    gasBudget: 1000,
  });
}

export async function deposit(
  signer: RawSigner, 
  multisigAccount: ObjectId,
  coinType: string,  // eg. "0x2::sui::SUI"
  coin: ObjectId,
  contract: SuiAddress,
): Promise<SuiExecuteTransactionResponse> {
  return await signer.executeMoveCall({
    packageObjectId: contract,
    module: 'sui_multisig',
    function: 'deposit',
    typeArguments: [
      coinType,
    ],
    arguments: [
      multisigAccount,
      coinType,
      coin
    ],
    gasBudget: 1000,
  });
}

export async function createTransaction(
  signer: RawSigner, 
  multisigAccount: ObjectId,
  balance: number,
  receiver: SuiAddress,
  transactionName: string,
  tokenType: string,
  lockedBefore: number = 0,
  contract: SuiAddress,
): Promise<SuiExecuteTransactionResponse> {
  return await signer.executeMoveCall({
    packageObjectId: contract,
    module: 'sui_multisig',
    function: 'create_transaction',
    typeArguments: [],
    arguments: [
      multisigAccount,
      balance,
      receiver,
      transactionName,
      tokenType,
      lockedBefore
    ],
    gasBudget: 1000,
  });
}

export async function approveTransaction(
  signer: RawSigner, 
  multisigAccount: ObjectId,
  approveCap: ObjectId,
  transactionName: string,
  contract: SuiAddress,
): Promise<SuiExecuteTransactionResponse> {
  return await signer.executeMoveCall({
    packageObjectId: contract,
    module: 'sui_multisig',
    function: 'approve_transaction',
    typeArguments: [],
    arguments: [
      approveCap,
      multisigAccount,
      transactionName,
    ],
    gasBudget: 1000,
  });
}

export async function executeTransaction(
  signer: RawSigner, 
  multisigAccount: ObjectId,
  transactionName: string,
  coinType: string,
  contract: SuiAddress,
): Promise<SuiExecuteTransactionResponse> {
  return await signer.executeMoveCall({
    packageObjectId: contract,
    module: 'sui_multisig',
    function: 'execute_transaction',
    typeArguments: [
      coinType
    ],
    arguments: [
      multisigAccount,
      transactionName,
    ],
    gasBudget: 1000,
  });
}

export async function cancelTransaction(
  signer: RawSigner, 
  multisigAccount: ObjectId,
  transactionName: string,
  contract: SuiAddress,
): Promise<SuiExecuteTransactionResponse> {
  return await signer.executeMoveCall({
    packageObjectId: contract,
    module: 'sui_multisig',
    function: 'cancel_transaction',
    typeArguments: [],
    arguments: [
      multisigAccount,
      transactionName,
    ],
    gasBudget: 1000,
  });
}