use core::starknet::{ContractAddress};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, spy_events, EventSpyAssertionsTrait,};
use hello_world::pokemon::{SpeciesType, IPokeStarknetDispatcher, IPokeStarknetDispatcherTrait, PokemonEvent, PokemonEventActionType};


fn deploy_contract(name: ByteArray) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}


#[test]
fn test_retrieve_pokemons(){
    let contract_address = deploy_contract("PokeStarknet");

    let dispatcher = IPokeStarknetDispatcher { contract_address };
    let res = dispatcher.get_pokemons();

    assert(res.is_empty() == false, 'get pokemons is empty');
    assert(res.len() == 3, 'nie rowna sie 3');

    let name: ByteArray =  "Pikachu";
    let p1 = dispatcher.get_pokemon(name);
    assert(p1.likes_counter == 0, 'get pokemon likes counter');
    assert(p1.id == 0, 'get pokemons id');
    assert(p1.species_type == SpeciesType::Fire, 'get pokemons SpeciesType');

    let name2: ByteArray =  "Charizard";
    let p2 = dispatcher.get_pokemon(name2);
    assert(p2.likes_counter == 0, 'get pokemon likes counter');
    assert(p2.id == 1, 'get pokemons id');
    assert(p2.species_type == SpeciesType::Water, 'get pokemons SpeciesType');

}   

#[test]
fn test_create_new_pokemon(){
    let contract_address = deploy_contract("PokeStarknet");
    let dispatcher = IPokeStarknetDispatcher { contract_address };
    
    dispatcher.vote("Charizard");  // get one token to pay for creating pokemon later
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
    dispatcher.vote("Bulbasaur");
    let pokemon = dispatcher.get_pokemon("Bulbasaur");
    assert(pokemon.likes_counter==1, 'nie rowna sie jeden');

    let is_liked: bool = dispatcher.user_likes_pokemon("Bulbasaur");
    assert(is_liked, 'is not liked');
}


#[test]
#[should_panic]
fn should_panic_exact() {
    let contract_address = deploy_contract("PokeStarknet");
    let dispatcher = IPokeStarknetDispatcher { contract_address };
    
    dispatcher.create_new_pokemon(name:"Pikachu", species_type: SpeciesType::Fire);
}


#[test]
#[should_panic(expected: 'ERC20: insufficient balance')]
fn should_panic_exact2() {
    let contract_address = deploy_contract("PokeStarknet");
    let dispatcher = IPokeStarknetDispatcher { contract_address };

    dispatcher.create_new_pokemon(name:"Squirtle", species_type: SpeciesType::Fire);
}


#[test]
fn test_events(){
    let contract_address = deploy_contract("PokeStarknet");
    let dispatcher = IPokeStarknetDispatcher { contract_address };

    let mut spy = spy_events();
    dispatcher.vote("Bulbasaur");

    dispatcher.vote("Charizard");  // get one token to pay for creating pokemon later
    dispatcher.create_new_pokemon(name:"Felicia", species_type: SpeciesType::Fire);

    spy.assert_emitted(
            @array![
            (
                contract_address,
                hello_world::pokemon::PokeStarknet::Event::PokemonEvent(
                PokemonEvent {id: 2, name: "Bulbasaur", action:PokemonEventActionType::Liked}
            )
            ),
            (
                contract_address,
                hello_world::pokemon::PokeStarknet::Event::PokemonEvent(
                PokemonEvent {id: 3, name: "Felicia", action:PokemonEventActionType::Created}
            )
            ),
        ]
    )

    


}


