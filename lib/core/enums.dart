// lib/core/enums.dart

enum TiempoDiscusion {
  unMinuto(60, '1 minuto'),
  dosMinutos(120, '2 minutos'),
  tresMinutos(180, '3 minutos'),
  cincoMinutos(300, '5 minutos');

  final int segundos;
  final String nombre;
  
  const TiempoDiscusion(this.segundos, this.nombre);
}

enum EstadoJugador {
  vivo,
  eliminado,
}

enum TipoGanador {
  impostor,
  jugadores,
}