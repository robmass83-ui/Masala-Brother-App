/// Initial categories & properties for `households/main`.
class SeedData {
  const SeedData._();

  static const categories = <({String id, String name, int order})>[
    (id: 'bollette', name: 'Bollette', order: 0),
    (id: 'condominio', name: 'Condominio', order: 1),
    (id: 'lavori', name: 'Lavori e fatture', order: 2),
    (id: 'tasse', name: 'Tasse e tributi', order: 3),
    (id: 'notaio', name: 'Notaio e pratiche', order: 4),
    (id: 'assicurazioni', name: 'Assicurazioni', order: 5),
    (id: 'altro', name: 'Altro', order: 6),
  ];

  static const properties = <({
    String id,
    String name,
    String shortName,
    int order,
    String street,
    String houseNumber,
    String city,
  })>[
    (
      id: 'forlanini',
      name: 'Via Forlanini',
      shortName: 'Forlanini',
      order: 0,
      street: 'Via Forlanini',
      houseNumber: '9',
      city: '',
    ),
    (
      id: 'addis',
      name: 'Via Addis',
      shortName: 'Addis',
      order: 1,
      street: 'Via Addis',
      houseNumber: '',
      city: '',
    ),
    (
      id: 'prunizzedda',
      name: 'Via Prunizzedda',
      shortName: 'Prunizzedda',
      order: 2,
      street: 'Via Prunizzedda',
      houseNumber: '',
      city: '',
    ),
    (
      id: 'sassari',
      name: 'Sassari / altro',
      shortName: 'Sassari',
      order: 3,
      street: '',
      houseNumber: '',
      city: 'Sassari',
    ),
  ];
}
