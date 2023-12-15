library;

abi SRC3 {
    /// Mints new tokens using the `vault_sub_id` sub-identifier.
    ///
    /// # Arguments
    ///
    /// * `recipient`: [Identity] - The user to which the newly minted tokens are transferred to.
    /// * `vault_sub_id`: [SubId] - The sub-identifier of the newly minted token.
    /// * `amount`: [u64] - The quantity of tokens to mint.
    ///
    /// # Examples
    ///
    /// ```sway
    /// use src3::SRC3;
    ///
    /// fn foo(contract_id: ContractId) {
    ///     let contract_abi = abi(SR3, contract);
    ///     contract_abi.mint(Identity::ContractId(contract_id), ZERO_B256, 100);
    /// }
    /// ```
    #[storage(read, write)]
    fn mint(recipient: Identity, vault_sub_id: SubId, amount: u64);

    /// Burns tokens sent with the given `vault_sub_id`.
    ///
    /// # Additional Information
    ///
    /// NOTE: The sha-256 hash of `(ContractId, SubId)` must match the `AssetId` where `ContractId` is the id of
    /// the implementing contract and `SubId` is the given `vault_sub_id` argument.
    ///
    /// # Arguments
    ///
    /// * `vault_sub_id`: [SubId] - The sub-identifier of the token to burn.
    /// * `amount`: [u64] - The quantity of tokens to burn.
    ///
    /// # Examples
    ///
    /// ```sway
    /// use src3::SRC3;
    ///
    /// fn foo(contract_id: ContractId, asset_id: AssetId) {
    ///     let contract_abi = abi(SR3, contract_id);
    ///     contract_abi {
    ///         gas: 10000,
    ///         coins: 100,
    ///         asset_id: asset_id,
    ///     }.burn(ZERO_B256, 100);
    /// }
    /// ```
    #[storage(read, write)]
    fn burn(vault_sub_id: SubId, amount: u64);
}
