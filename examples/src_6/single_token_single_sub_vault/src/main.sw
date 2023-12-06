contract;

use std::{
    call_frames::msg_asset_id,
    context::msg_amount,
    hash::{
        Hash,
        sha256,
    },
    storage::{
        storage_map::*,
        storage_string::*,
    },
    string::String,
    token::{
        transfer,
    },
};

use src_6::{Deposit, SRC6, Withdraw};
use src_20::SRC20;

configurable {
    ACCEPTED_TOKEN: AssetId = std::constants::BASE_ASSET_ID,
    ACCEPTED_SUB_VAULT: SubId = std::constants::ZERO_B256,
    PRE_CALCULATED_SHARE_SUB_ID: SubId = 0xf5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b,
}

storage {
    managed_assets: u64 = 0,
    total_assets: u64 = 0,
    total_supply: u64 = 0,
    minted: bool = false,
}

impl SRC6 for Contract {
    #[storage(read)]
    fn managed_assets(asset: AssetId, sub_id: SubId) -> u64 {
        if asset == ACCEPTED_TOKEN && sub_id == ACCEPTED_SUB_VAULT {
            // In this implementation managed_assets and max_withdrawable are the same. However in case of lending out of assets, managed_assets should be greater than max_withdrawable.
            storage.managed_assets.read()
        } else {
            0
        }
    }

    #[storage(read, write)]
    fn deposit(receiver: Identity, sub_id: SubId) -> u64 {
        require(sub_id == ACCEPTED_SUB_VAULT, "INVALID_SUB_ID");

        let asset = msg_asset_id();
        require(asset == ACCEPTED_TOKEN, "INVALID_ASSET_ID");

        let asset_amount = msg_amount();
        let (shares, share_asset) = preview_deposit(asset_amount);
        require(asset_amount != 0, "ZERO_ASSETS");

        _mint(receiver, share_asset, shares);
        storage.total_supply.write(storage.total_supply.read() + shares);

        storage.managed_assets.write(storage.managed_assets.read() + asset_amount);

        log(Deposit {
            caller: msg_sender().unwrap(),
            receiver: receiver,
            asset: asset,
            sub_id: sub_id,
            assets: asset_amount,
            shares: shares,
        });

        shares
    }

    #[storage(read, write)]
    fn withdraw(receiver: Identity, asset: AssetId, sub_id: SubId) -> u64 {
        require(asset == ACCEPTED_TOKEN, "INVALID_ASSET_ID");
        require(sub_id == ACCEPTED_SUB_VAULT, "INVALID_SUB_ID");

        let shares = msg_amount();
        require(shares != 0, "ZERO_SHARES");

        let share_asset_id = vault_assetid();

        require(msg_asset_id() == share_asset_id, "INVALID_ASSET_ID");
        let assets = preview_withdraw(shares);

        _burn(share_asset_id, shares);
        storage.total_supply.write(storage.total_supply.read() - shares);

        transfer(receiver, asset, assets);

        log(Withdraw {
            caller: msg_sender().unwrap(),
            receiver: receiver,
            asset: asset,
            sub_id: sub_id,
            assets: assets,
            shares: shares,
        });

        assets
    }

    #[storage(read)]
    fn max_depositable(receiver: Identity, asset: AssetId, sub_id: SubId) -> Option<u64> {
        if asset == ACCEPTED_TOKEN {
            // This is the max value of u64 minus the current managed_assets. Ensures that the sum will always be lower than u64::MAX.
            Some(u64::max() - storage.managed_assets.read())
        } else {
            None
        }
    }

    #[storage(read)]
    fn max_withdrawable(asset: AssetId, sub_id: SubId) -> Option<u64> {
        if asset == ACCEPTED_TOKEN {
            // In this implementation total_assets and max_withdrawable are the same. However in case of lending out of assets, total_assets should be greater than max_withdrawable.
            Some(storage.managed_assets.read())
        } else {
            None
        }
    }
}

impl SRC20 for Contract {
    #[storage(read)]
    fn total_assets() -> u64 {
        1
    }

    #[storage(read)]
    fn total_supply(asset: AssetId) -> Option<u64> {
        Some(storage.total_supply.read())
    }

    #[storage(read)]
    fn name(asset: AssetId) -> Option<String> {
        Some(String::from_ascii_str("Vault Shares"))
    }

    #[storage(read)]
    fn symbol(asset: AssetId) -> Option<String> {
        Some(String::from_ascii_str("VLTSHR"))
    }

    #[storage(read)]
    fn decimals(asset: AssetId) -> Option<u8> {
        Some(9_u8)
    }
}

/// Returns the vault shares assetid for the given assets assetid and the vaults sub id
fn vault_assetid() -> AssetId {
    let share_asset_id = AssetId::new(ContractId::this(), PRE_CALCULATED_SHARE_SUB_ID);
    share_asset_id
}

#[storage(read)]
fn preview_deposit(assets: u64) -> (u64, AssetId) {
    let share_asset_id = vault_assetid();

    let shares_supply = storage.total_supply.read();
    if shares_supply == 0 {
        (assets, share_asset_id)
    } else {
        (
            assets * shares_supply / storage.managed_assets.read(),
            share_asset_id,
        )
    }
}

#[storage(read)]
fn preview_withdraw(shares: u64) -> u64 {
    let supply = storage.total_supply.read();
    if supply == shares {
        storage.managed_assets.read()
    } else {
        shares * (storage.managed_assets.read() / supply)
    }
}

#[storage(read, write)]
pub fn _mint(recipient: Identity, asset_id: AssetId, amount: u64) {
    use std::token::mint_to;

    let supply = storage.total_supply.read();
    storage.total_supply.write(supply + amount);
    mint_to(recipient, PRE_CALCULATED_SHARE_SUB_ID, amount);
}

#[storage(read, write)]
pub fn _burn(asset_id: AssetId, amount: u64) {
    use std::{context::this_balance, token::burn};

    require(this_balance(asset_id) >= amount, "BurnError::NotEnoughTokens");
    // If we pass the check above, we can assume it is safe to unwrap.
    let supply = storage.total_supply.read();
    storage.total_supply.write(supply - amount);
    burn(PRE_CALCULATED_SHARE_SUB_ID, amount);
}
