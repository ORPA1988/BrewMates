part of '../providers.dart';

/// Welche Anmeldewege der Anmeldebildschirm anbieten darf.
///
/// Kommt vom Server (`app_config.auth_providers`, Migration 0046), damit
/// ein freigeschalteter Anbieter **ohne neues Release** auftaucht — und
/// vor allem, damit kein Knopf dasteht, der nicht funktioniert.
///
/// **Hier steht die eine Regel: niemals leer.** Ein Anmeldebildschirm
/// ohne einen einzigen Knopf ist keine ehrliche Antwort auf ein
/// technisches Problem, sondern eine Sackgasse — der Mensch kann dann
/// gar nichts mehr tun. Bleibt Google: eingerichtet seit 0.9.2, und ein
/// Versuch, der hörbar scheitert, ist besser als eine leere Fläche.
///
/// Die Regel steht bewusst nur hier und nicht zusätzlich im
/// `OnlineService`: Der sagt, was der Server gesagt hat. Zwei Stellen mit
/// derselben Regel laufen beim ersten Umbau auseinander — und die eine,
/// die man vergisst, ist immer die, die der Nutzer sieht.
///
/// `autoDispose` bewusst nicht: Die Liste ändert sich im Minutentakt nie,
/// und der Anmeldebildschirm wird beim Abmelden ohnehin neu aufgebaut.
final anmeldeverfahrenProvider =
    FutureProvider<List<Anmeldeverfahren>>((ref) async {
  final online = await ref.watch(onlineServiceProvider.future);
  final vomServer = online == null
      ? const <Anmeldeverfahren>[]
      : await online.verfuegbareAnmeldeverfahren();
  return vomServer.isEmpty ? const [Anmeldeverfahren.google] : vomServer;
});
