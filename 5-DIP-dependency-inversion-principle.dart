// ignore_for_file: uri_does_not_exist, unused_import, undefined_class, undefined_method, undefined_identifier, non_type_as_type_argument

// ============================================================
// VERSÃO RUIM — viola o DIP
// ============================================================

// O módulo de ALTO nível (registrar a presença do entregador num pedido)
// depende DIRETAMENTE do plugin Geolocator — um detalhe de baixo nível.
class EntregaController {
  Future<void> registrarChegada(Pedido pedido) async {
    // ...regra de negócio da entrega...

    // A política fala a língua do plugin: checa serviço, pede permissão,
    // recebe um Position do geolocator. Tudo amarrado ao detalhe.
    final servicoAtivo = await Geolocator.isLocationServiceEnabled();
    if (!servicoAtivo) throw Exception('GPS desligado');

    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }

    final Position pos = await Geolocator.getCurrentPosition();

    await Api().post(
      '/pedidos/${pedido.id}/chegada',
      data: {'lat': pos.latitude, 'lng': pos.longitude},
    );
  }
}

// Problemas:
// 1. Não dá para testar registrarChegada sem GPS / device real.
// 2. Trocar geolocator por location (ou um mock em web) obriga a mexer na regra.
// 3. O domínio depende de Position e da API de permissões do plugin.
//    A seta aponta do alto nível para o concreto.

// ============================================================
// VERSÃO NOVA — respeita o DIP
// ============================================================

// Tipo do DOMÍNIO: a regra fala "coordenada", não "Position do geolocator".
class Coordenada {
  final double latitude;
  final double longitude;
  const Coordenada({required this.latitude, required this.longitude});
}

// A abstração é DEFINIDA pelo alto nível, no vocabulário do domínio:
// "me diga a localização atual" — sem permissão, sem serviço, sem plugin.
abstract class LocalizadorUsuario {
  Future<Coordenada> localizacaoAtual();
}

// O ALTO nível depende só da abstração. Não sabe de onde vem a coordenada.
class EntregaController2 {
  final LocalizadorUsuario _localizador;
  EntregaController2(this._localizador);

  Future<void> registrarChegada(Pedido pedido) async {
    // ...regra de negócio da entrega...

    final local = await _localizador.localizacaoAtual();

    await Api().post(
      '/pedidos/${pedido.id}/chegada',
      data: {'lat': local.latitude, 'lng': local.longitude},
    );
  }
}

// O BAIXO nível implementa a abstração do domínio. É AQUI que mora toda a
// dança de permissão, serviço e conversão de Position — isolada numa borda.
class GeolocatorLocalizador implements LocalizadorUsuario {
  @override
  Future<Coordenada> localizacaoAtual() async {
    final servicoAtivo = await Geolocator.isLocationServiceEnabled();
    if (!servicoAtivo) throw Exception('GPS desligado');

    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }

    final pos = await Geolocator.getCurrentPosition();
    // tradução Position -> Coordenada fica encapsulada aqui.
    return Coordenada(latitude: pos.latitude, longitude: pos.longitude);
  }
}

// Trocar de plugin é só outra implementação — a regra não muda.
class LocationPackageLocalizadorAdapter implements LocalizadorUsuario {
  @override
  Future<Coordenada> localizacaoAtual() async {
    final dados = await Location().getLocation();
    return Coordenada(latitude: dados.latitude!, longitude: dados.longitude!);
  }
}

// Testar a entrega fica trivial: um fake com coordenada fixa, sem GPS.
class FakeLocalizador implements LocalizadorUsuario {
  final Coordenada fixa;
  FakeLocalizador(this.fixa);

  @override
  Future<Coordenada> localizacaoAtual() async => fixa;
}

// A escolha do plugin concreto acontece na BORDA (injeção de dependência),
// nunca dentro da regra de negócio.
void exemploComposicao() {
  final entregaReal = EntregaController2(GeolocatorLocalizador());
  final entregaTeste = EntregaController2(
    FakeLocalizador(const Coordenada(latitude: -23.5, longitude: -51.6)),
  );
  // mesma regra de negócio, fonte de localização plugável.
}
