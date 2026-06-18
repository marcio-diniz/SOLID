// ignore_for_file: uri_does_not_exist, unused_import, undefined_class, undefined_method, undefined_identifier, non_type_as_type_argument

// ============================================================
// VERSÃO RUIM — viola o LSP
// ============================================================

abstract class Cache<T> {
  Future<void> salvar(String chave, T valor);
  Future<T?> ler(String chave);
}

class MemoryCache<T> implements Cache<T> {
  final _dados = <String, T>{};

  @override
  Future<void> salvar(String chave, T valor) async {
    // Guarda a REFERÊNCIA do objeto recebido.
    _dados[chave] = valor;
  }

  @override
  Future<T?> ler(String chave) async => _dados[chave];
}

class SharedPrefsCache implements Cache<String> {
  @override
  Future<void> salvar(String chave, String valor) async {
    // SERIALIZA o valor no disco no momento do salvar.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(chave, valor);
  }

  @override
  Future<String?> ler(String chave) async {
    // RECONSTRÓI um novo objeto a partir dos bytes.
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(chave);
  }
}

class CarrinhoController {
  final Cache<List<int>> _cache;
  CarrinhoController(this._cache);

  Future<void> exemplo() async {
    final itens = [1, 2, 3];

    await _cache.salvar('itens', itens);

    itens.add(4);

    final lido = await _cache.ler('itens');

    // MemoryCache:        [1, 2, 3, 4] — guardou a referência, mutação vazou
    // Cache serializado:  [1, 2, 3]    — copiou no instante do salvar
    //
    // Mesma chamada, resultado diferente conforme a implementação.
    // O subtipo NÃO é substituível: o cliente precisa saber qual cache usa
    // para prever o resultado. Os tipos batem, o analyzer não reclama.
    print(lido);
  }
}

// ============================================================
// VERSÃO NOVA — respeita o LSP
// ============================================================

// O contrato passa a ser EXPLÍCITO: toda implementação devolve um valor
// independente do objeto original. Quem guarda referência precisa copiar
// na entrada e na saída para honrar a mesma promessa que a versão serializada.
abstract class Cache2<T> {
  /// Guarda uma cópia independente de [valor].
  /// Mutações no objeto original após o salvar NÃO afetam o cache.
  Future<void> salvar(String chave, T valor);

  /// Devolve uma cópia independente do valor guardado.
  Future<T?> ler(String chave);
}

class MemoryCache2<T> implements Cache2<T> {
  final _dados = <String, T>{};
  final T Function(T) _copiar;

  // A cópia vira responsabilidade explícita da implementação,
  // injetada por quem conhece o tipo T.
  MemoryCache2({required T Function(T) copiar}) : _copiar = copiar;

  @override
  Future<void> salvar(String chave, T valor) async {
    _dados[chave] = _copiar(valor); // copia na entrada
  }

  @override
  Future<T?> ler(String chave) async {
    final valor = _dados[chave];
    return valor == null ? null : _copiar(valor); // copia na saída
  }
}

class SharedPrefsCache2<T> implements Cache2<T> {
  final String Function(T) _serializar;
  final T Function(String) _desserializar;

  // A serialização também vira explícita: aceita qualquer T,
  // desde que se saiba converter de/para String.
  SharedPrefsCache2({
    required String Function(T) serializar,
    required T Function(String) desserializar,
  }) : _serializar = serializar,
       _desserializar = desserializar;

  @override
  Future<void> salvar(String chave, T valor) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(chave, _serializar(valor));
  }

  @override
  Future<T?> ler(String chave) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(chave);
    return raw == null ? null : _desserializar(raw);
  }
}

// Agora o cliente é substituível de verdade: as duas implementações
// honram a mesma promessa ("devolvo um valor independente"), então o
// resultado não depende mais de qual Cache foi injetado.
class CarrinhoController2 {
  final Cache2<List<int>> _cache;
  CarrinhoController2(this._cache);

  Future<void> exemplo() async {
    final itens = [1, 2, 3];

    await _cache.salvar('itens', itens);

    itens.add(4); // muta o original

    final lido = await _cache.ler('itens');

    // MemoryCache:        [1, 2, 3] — copiou na entrada, mutação não vazou
    // SharedPrefsCache:   [1, 2, 3] — serializou no salvar
    //
    // Mesmo comportamento, independente da implementação. LSP respeitado.
    print(lido);
  }
}
