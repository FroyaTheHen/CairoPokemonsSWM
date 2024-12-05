use starknet::{ContractAddress};


#[derive(Serde, Debug, Drop, Copy, PartialEq, starknet::Store)]
pub enum SpeciesType {
    #[default]
    Water,
    Fire,
    Grass
}


#[derive(Serde, Clone, Debug, Drop, PartialEq, starknet::Store)]
pub struct Pokemon {
    pub name: ByteArray,  // TODO: guarantee uniqe ? 
    pub species_type: SpeciesType,
    pub likes_counter: u64,
    pub id: felt252,  // id maps to index in storage pokemons attr
    pub owner: ContractAddress,
}


#[generate_trait]
pub impl PokemonImpl of PokemonTrait {
    fn like(ref self: Pokemon) {
        self.likes_counter += 1;
    }
    
}


#[starknet::interface]
pub trait IPokeStarknet<TContractState> {
    fn vote(ref self: TContractState, name: ByteArray);
    fn create_new_pokemon(ref self: TContractState, name: ByteArray, species_type: SpeciesType);
    fn get_pokemons_count(self: @TContractState) -> felt252;
    fn increase_poke_count(ref self: TContractState);
    fn get_pokemons(self: @TContractState) -> Array<Pokemon>;
    fn get_pokemon(self: @TContractState, name: ByteArray) -> Pokemon; // TODO: make optional
    fn get_pokemon_with_index(self: @TContractState, name: ByteArray) -> (Pokemon, felt252);
    fn user_likes_pokemon(ref self: TContractState, name: ByteArray) -> bool;
}

#[starknet::contract]
mod PokeStarknet {
use super::IPokeStarknet;
use core::starknet::storage::{StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map};
    use core::starknet::{ContractAddress, get_caller_address};
    use super::*;

    #[storage]
    struct Storage {
        pokemon_count: felt252,
        pokemons: Map<felt252, Pokemon>,
        likes_map: Map<ContractAddress, Map<felt252, bool>>, // user id <pokemon id, ~/liked 
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, 
    ) {
        let owner: ContractAddress = get_caller_address();
        let pokemon1 = Pokemon {
            name: "first random pokemon",
            species_type: SpeciesType::Fire,
            likes_counter: 0,
            id: 0,
            owner: owner,
        };
        let pokemon2 = Pokemon {
            name: "second random pokemon",
            species_type: SpeciesType::Water,
            likes_counter: 0,
            id: 1,
            owner: owner,
        };
        let pokemon3 = Pokemon {
            name: "third random pokemon",
            species_type: SpeciesType::Grass,
            likes_counter: 0,
            id: 2,
            owner: owner,
        };
        self.pokemons.write(0, pokemon1);
        self.pokemons.write(1, pokemon2);
        self.pokemons.write(2, pokemon3);

        self.pokemon_count.write(3);
    }  


    #[abi(embed_v0)]
    impl PokeStarknetImpl of super::IPokeStarknet<ContractState> {
        fn create_new_pokemon(ref self: ContractState, name: ByteArray, species_type: SpeciesType
        ) {
            let owner: ContractAddress = get_caller_address();
            let new_pokemon = Pokemon { 
                name: name,
                species_type: species_type,
                likes_counter: 0,
                id: self.pokemon_count.read().into(),
                owner: owner,
            };
            self.pokemons.write(3, new_pokemon);
            self.increase_poke_count();
        }

        fn vote(ref self: ContractState, name: ByteArray) {
            let (mut pokemon, index) =  self.get_pokemon_with_index(name);
            pokemon.like();            

            self.pokemons.write(index, pokemon);
            let caller = get_caller_address();
            self.likes_map.entry(caller).entry(index).write(true);
            // one-pokemon can be liked only once per user 
            // but we don't care cuse the value gets overrden each time
        }

        fn get_pokemons_count(self: @ContractState) -> felt252 {
            self.pokemon_count.read()
        }

        fn increase_poke_count(ref self: ContractState) {
            let count: felt252 = 1;
            self.pokemon_count.write(self.pokemon_count.read() + count);
        }

        fn get_pokemons(self: @ContractState) -> Array<Pokemon> {
            let mut pokemons: Array<Pokemon> = ArrayTrait::new();
            let mut i = 0;
            let poke_count = self.pokemon_count.read();

            while i != poke_count {
                pokemons.append(self.pokemons.entry(i).read());
                i += 1;
            };
            pokemons
        }

        fn get_pokemon(self: @ContractState, name: ByteArray) -> Pokemon {
            let (mut pokemon, _index) =  self.get_pokemon_with_index(name);
            pokemon
        }

        fn get_pokemon_with_index(self: @ContractState, name: ByteArray) -> (Pokemon, felt252) {
            let poke_count = self.pokemon_count.read();
            let mut i = poke_count;

            let result = loop {
                let mut pokemon: Pokemon = self.pokemons.read(i);
                if name == pokemon.name {
                    break pokemon;
                }
                i -= 1;
            }; 
            (result, i)
        }

        fn user_likes_pokemon(ref self: ContractState, name: ByteArray) -> bool {
            let caller: ContractAddress = get_caller_address();
            let (mut _pokemon, index) =  self.get_pokemon_with_index(name);
            self.likes_map.entry(caller).entry(index).read()
        }

    }
}
