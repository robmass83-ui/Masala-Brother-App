import 'dart:math' as math;

/// Frasi di Penny nella nuvoletta. Solo il testo, senza numeri.
const List<String> pennyThoughts = [
  'Penny ha rosicchiato il divano.',
  'Secondo Penny, russo troppo.',
  'Ho perso contro Penny. Di nuovo.',
  'Penny trama qualcosa. Lo sento.',
  'Suggerisco di rapire Toby.',
  'Piano B: rapire il postino.',
  'Ho un piano. Fallirà.',
  'Stanotte colpo grosso: il frigo.',
  'Colpo di stato sul cuscino.',
  'Piano segreto: l’ho scordato.',
  'Ho abbaiato al postino. Ancora.',
  'Fingevo di dormire. Origliavo tutto.',
  'Sono stato bravo. Premio, ora.',
  'Piove. Passeggiata rimandata a data futura.',
  'Ho nascosto un osso. Sparito.',
  'Ho fissato il muro. Riunione importante.',
  'Ho starnutito. Mi sono spaventato.',
  'Ho inseguito la coda. Persa.',
  'Ho ululato con l’ambulanza. Duetto.',
  'Dormito 18 ore. Domani di più.',
  'Di nuovo qui? Ti affezioni.',
  'Sei un bravo umano. Bravo.',
  'Stavo per dire qualcosa. Forse no.',
  'Mi apri e mi sento importante.',
  'Ti giudico con amore, sempre.',
  'Penserò a te comunque, chiudi pure.',
  'Non sono un cane qualunque.',
  'Torno sempre, tra un pensiero e l’altro.',
  'La vita è una ciotola vuota.',
  'Non tutti gli eroi hanno il collare.',
  'Un giorno senza carezze è perso.',
  'Rapirò il postino stasera.',
  'Piano: nascondere tutte le ciabatte.',
  'Ho reclutato una spia. Il gatto del vicino.',
  'Obiettivo di stanotte: il salame.',
  'Ho scavato un tunnel. Verso la cucina.',
  'Complotto in corso. Sh, silenzio.',
  'Rapirò il divano. Metaforicamente.',
  'Piano infallibile versione 47.',
  'Stanotte si agisce. Forse.',
  'Ho un alleato segreto. Il criceto.',
  'Colpo grosso: la dispensa.',
  'Rapimento lampo del cuscino preferito.',
  'Piano B, C e D pronti.',
  'Ho mappato la casa. Per motivi.',
  'Missione: recuperare l’osso perduto.',
  'Sto tramando. Non chiedere.',
  'Ho un covo segreto. Sotto il letto.',
  'Operazione crocchette è iniziata.',
  'Rapirò la ciotola vuota. Simbolicamente.',
  'Piano geniale. Dettagli top secret.',
];

/// Una frase per processo: cambia solo chiudendo e riaprendo l’app.
class PennySession {
  static String? _phrase;
  static final _rng = math.Random();

  static String get phrase =>
      _phrase ??= pennyThoughts[_rng.nextInt(pennyThoughts.length)];

  static void resetForTest() => _phrase = null;
}
