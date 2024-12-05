use core::traits::IndexView;
use core::starknet::{ContractAddress, get_caller_address};

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

use hello_world::IHelloStarknetSafeDispatcher; 
use hello_world::IHelloStarknetSafeDispatcherTrait;
use hello_world::IHelloStarknetDispatcher;
use hello_world::IHelloStarknetDispatcherTrait;
use hello_world::pokemon::{Pokemon, SpeciesType};

use hello_world::pokemon::IPokeStarknetDispatcher;  // wtf??
use hello_world::pokemon::IPokeStarknetDispatcherTrait;


fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[test]
fn test_increase_balance() {
    let contract_address = deploy_contract("HelloStarknet");

    let dispatcher = IHelloStarknetDispatcher { contract_address };

    let balance_before = dispatcher.get_balance();
    assert(balance_before == 0, 'Invalid balance');

    dispatcher.increase_balance(42);

    let balance_after = dispatcher.get_balance();
    assert(balance_after == 42, 'Invalid balance');
}

#[test]
#[feature("safe_dispatcher")]
fn test_cannot_increase_balance_with_zero_value() {
    let contract_address = deploy_contract("HelloStarknet");

    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

    let balance_before = safe_dispatcher.get_balance().unwrap();
    assert(balance_before == 0, 'Invalid balance');

    match safe_dispatcher.increase_balance(0) {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Amount cannot be 0', *panic_data.at(0));
        }
    };
}


#[test]
fn test_pokemons_count() {
    let contract_address = deploy_contract("PokeStarknet");

    let dispatcher = IPokeStarknetDispatcher { contract_address };
    let pokemons_before = dispatcher.get_pokemons_count();

    assert(pokemons_before == 3, 'pokemons count before faield');
    dispatcher.increase_poke_count();
    let balance_after = dispatcher.get_pokemons_count();
    assert(balance_after == 4, balance_after);
}

#[test]
fn test_retrieve_pokemons(){
    let contract_address = deploy_contract("PokeStarknet");

    let dispatcher = IPokeStarknetDispatcher { contract_address };
    let res = dispatcher.get_pokemons();

    assert(res.is_empty() == false, 'Xdxd');
    assert(res.len() == 3, 'nie rowna sie 3');

    let name: ByteArray =  "first random pokemon";
    let p1 = dispatcher.get_pokemon(name);
    assert(p1.likes_counter == 0, 'get pokemon likes counter');
    assert(p1.id == 0, 'get pokemons id');
    assert(p1.species_type == SpeciesType::Fire, 'get pokemons SpeciesType');

    let name2: ByteArray =  "second random pokemon";
    let p2 = dispatcher.get_pokemon(name2);
    assert(p2.likes_counter == 0, 'get pokemon likes counter');
    assert(p2.id == 1, 'get pokemons id');
    assert(p2.species_type == SpeciesType::Water, 'get pokemons SpeciesType');

}   

#[test]
fn test_create_new_pokemon(){
    let contract_address = deploy_contract("PokeStarknet");
    let dispatcher = IPokeStarknetDispatcher { contract_address };
    
    dispatcher.create_new_pokemon(name:"Felicia", species_type: SpeciesType::Fire);
    let felicia = dispatcher.get_pokemon("Felicia");
    
    assert(felicia.id == 3, felicia.id);
    assert(dispatcher.get_pokemons_count() == 4, dispatcher.get_pokemons_count());
    assert(felicia.species_type == SpeciesType::Fire, 'SpeciesType failed');
    assert(felicia.name == "Felicia", 'name failed');
}


#[test]
fn test_voting_pokemon(){
    let contract_address = deploy_contract("PokeStarknet");
    let dispatcher = IPokeStarknetDispatcher { contract_address };
    dispatcher.vote("third random pokemon");
    let pokemon = dispatcher.get_pokemon("third random pokemon");
    assert(pokemon.likes_counter==1, 'nie rowna sie jeden');

    let is_liked: bool = dispatcher.user_likes_pokemon("third random pokemon");
    assert(is_liked, 'is not liked');

    // TODO: add test simulating another user
}
