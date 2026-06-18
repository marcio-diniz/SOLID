// ignore_for_file: uri_does_not_exist, unused_import, undefined_class, undefined_method, undefined_identifier, non_type_as_type_argument

// ============================================================
// VERSÃO RUIM — viola o ISP
// ============================================================

// Interface "gorda": assume que toda fonte de dados suporta CRUD completo.
abstract class Repository<T> {
  Future<List<T>> getAll();
  Future<T> getById(String id);
  Future<void> create(T item);
  Future<void> update(T item);
  Future<void> delete(String id);
}

// Uma fonte completa (API com escrita) implementa tudo de verdade.
class ProductRepository implements Repository<Product> {
  @override
  Future<List<Product>> getAll() async => [];

  @override
  Future<Product> getById(String id) async => Product();

  @override
  Future<void> create(Product item) async {}

  @override
  Future<void> update(Product item) async {}

  @override
  Future<void> delete(String id) async {}
}

// Mas um feed de notícias é READ-ONLY. Não existe "criar notícia"
// do lado do app. A interface gorda força a implementar mesmo assim.
class NewsRepository implements Repository<Article> {
  @override
  Future<List<Article>> getAll() async => []; // ok

  @override
  Future<Article> getById(String id) async => Article(); // ok

  // A partir daqui só sobra "mentir": implementar métodos que não
  // fazem sentido para esta fonte, só para satisfazer a interface.
  @override
  Future<void> create(Article item) =>
      throw UnimplementedError('NewsRepository é read-only');

  @override
  Future<void> update(Article item) =>
      throw UnimplementedError('NewsRepository é read-only');

  @override
  Future<void> delete(String id) =>
      throw UnimplementedError('NewsRepository é read-only');
}

// Consequência dupla:
// 1. A implementação fica suja, cheia de UnimplementedError.
// 2. O cliente recebe Repository<Article> e o TIPO diz que pode deletar.
//    Quebra em runtime — a interface gorda quase força uma violação de LSP.
class NoticiasController {
  final Repository<Article> _repo;
  NoticiasController(this._repo);

  // se chegar a chamar
  Future<void> limpar(String id) async {
    await _repo.delete(id); // compila, mas estoura UnimplementedError
  }
}

// ============================================================
// VERSÃO NOVA — respeita o ISP
// ============================================================

// Interfaces pequenas e coesas: leitura e escrita separadas.
abstract class ReadableRepository<T> {
  Future<List<T>> getAll();
  Future<T> getById(String id);
}

abstract class WritableRepository<T> {
  Future<void> create(T item);
  Future<void> update(T item);
  Future<void> delete(String id);
}

// A fonte read-only implementa SÓ o que faz sentido. Sem UnimplementedError.
class NewsRepository2 implements ReadableRepository<Article> {
  @override
  Future<List<Article>> getAll() async => [];

  @override
  Future<Article> getById(String id) async => Article();
}

// A fonte completa COMPÕE as duas interfaces, porque de fato suporta tudo.
class ProductRepository2
    implements ReadableRepository<Product>, WritableRepository<Product> {
  @override
  Future<List<Product>> getAll() async => [];

  @override
  Future<Product> getById(String id) async => Product();

  @override
  Future<void> create(Product item) async {}

  @override
  Future<void> update(Product item) async {}

  @override
  Future<void> delete(String id) async {}
}

// O cliente depende APENAS do que precisa. Quem só lê pede ReadableRepository
// e nem enxerga delete — fica impossível chamar o que não existe.
class NoticiasController2 {
  final ReadableRepository<Article> _repo;
  NoticiasController2(this._repo);

  Future<List<Article>> carregar() async {
    return _repo.getAll(); // só o que a fonte realmente oferece
  }
}
