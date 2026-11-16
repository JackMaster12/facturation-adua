import 'package:flutter/material.dart';

class Fiche {
  const Fiche(this.nom, this.famille, this.usage, this.precautions, this.conseil);
  final String nom;
  final String famille;
  final String usage;
  final String precautions;
  final String conseil;
}

class ThemeSante {
  const ThemeSante(this.id, this.titre, this.icone, this.couleur, this.intro, this.alertes, this.fiches);
  final String id;
  final String titre;
  final IconData icone;
  final Color couleur;
  final String intro;
  final List<String> alertes;
  final List<Fiche> fiches;
}

const String avertissementApprendre =
    "Contenu éducatif destiné au personnel du dépôt. Il ne remplace ni l'ordonnance, ni l'avis d'un médecin ou d'un pharmacien, ni les protocoles nationaux de santé. Les doses ne sont pas indiquées : suivre la notice, l'ordonnance et le protocole en vigueur.";

const List<ThemeSante> themesSante = [
  ThemeSante("palu", "Paludisme", Icons.bug_report, Color(0xFFC62828), "Maladie transmise par la piqûre de l'anophèle. Signes : fièvre, frissons, maux de tête, courbatures, vomissements. On confirme par un test de diagnostic rapide (TDR) ou une goutte épaisse avant de traiter. Prévention : moustiquaire imprégnée, chimioprévention saisonnière chez le jeune enfant, traitement préventif chez la femme enceinte.", [
    "Convulsions, somnolence ou perte de connaissance",
    "Vomissements répétés : le malade ne garde pas son traitement",
    "Pâleur marquée, respiration rapide, urines très foncées",
    "Fièvre chez un enfant de moins de 5 ans qui ne baisse pas : l'orienter vers un centre de santé le jour même",
  ], [
    Fiche("Artéméther + luméfantrine (AL)", "Combinaison thérapeutique à base d'artémisinine (CTA)", "Traitement du paludisme simple à Plasmodium falciparum. Cure de 3 jours, deux prises par jour.", "À prendre avec un repas ou une boisson grasse (lait) pour être bien absorbé. Si le malade vomit peu après la prise, redonner la dose. Éviter avec des médicaments qui allongent le QT. Grossesse : avis du médecin. Dose selon le poids ou l'âge : voir la notice et l'ordonnance.", "Insister pour que toute la cure soit terminée, même si la fièvre disparaît dès le premier jour."),
    Fiche("Artésunate + amodiaquine (ASAQ)", "Combinaison thérapeutique à base d'artémisinine (CTA)", "Traitement du paludisme simple. Cure de 3 jours, une prise par jour, en comprimés selon le poids ou l'âge.", "Possible somnolence, nausées, douleurs abdominales. Ne pas utiliser l'amodiaquine en traitement préventif prolongé hors protocole. Contre-indiquée en cas d'allergie à l'amodiaquine.", "Prendre à heure fixe, de préférence avec un peu de nourriture."),
    Fiche("Artésunate injectable", "Antipaludique, forme injectable", "Traitement de première intention du paludisme grave (voie intraveineuse ou intramusculaire) en structure de santé.", "Réservé au personnel de santé. Après l'amélioration du malade, un traitement complet par CTA par voie orale est donné pour terminer la guérison.", "Un paludisme grave est une urgence : ne jamais retarder le transfert."),
    Fiche("Artésunate suppositoire (avant transfert)", "Antipaludique, forme rectale", "Dose unique donnée à un jeune enfant très malade juste avant son transfert vers un centre de santé, quand l'injection est impossible.", "Ne remplace pas le traitement complet : le malade doit absolument être vu par un soignant.", "Expliquer aux parents qu'il faut partir tout de suite après avoir donné le suppositoire."),
    Fiche("Sulfadoxine-pyriméthamine (SP)", "Antipaludique (prévention)", "Traitement préventif intermittent de la femme enceinte, à partir du deuxième trimestre, en doses espacées d'au moins un mois. Utilisée aussi avec l'amodiaquine pour la chimioprévention saisonnière du jeune enfant.", "Contre-indiquée en cas d'allergie aux sulfamides. Ne pas associer au cotrimoxazole. Pas pendant le premier trimestre de la grossesse.", "Se donne en consultation prénatale ou lors des campagnes saisonnières : respecter le calendrier."),
    Fiche("Quinine", "Antipaludique", "Alternative quand les CTA ne sont pas disponibles ou ne conviennent pas, selon protocole médical.", "Peut provoquer bourdonnements d'oreilles, vertiges et hypoglycémie. Surdosage dangereux. Uniquement sur prescription.", "Surveiller la glycémie chez le malade grave et la femme enceinte."),
  ]),
  ThemeSante("douleur", "Fièvre et douleur", Icons.thermostat, Color(0xFFEF6C00), "La fièvre est un signe, pas une maladie. On traite d'abord la cause (paludisme, infection). Les antalgiques soulagent la douleur et font baisser la température. Toujours respecter la dose et l'intervalle indiqués.", [
    "Fièvre chez un nourrisson de moins de 3 mois",
    "Raideur de la nuque, éruption qui ne s'efface pas à la pression, convulsions",
    "Fièvre qui dure plus de 3 jours",
    "Douleur très intense ou qui s'aggrave",
  ], [
    Fiche("Paracétamol", "Antalgique et antipyrétique", "Fièvre et douleurs légères à modérées. Médicament de première intention chez l'enfant et l'adulte.", "Ne jamais dépasser la dose maximale par jour : le surdosage abîme le foie. Vérifier que les autres médicaments pris (sirops, poudres contre le rhume) ne contiennent pas déjà du paracétamol. Respecter l'intervalle minimal entre deux prises.", "Dose de l'enfant selon son poids : voir la notice du produit."),
    Fiche("Ibuprofène", "Anti-inflammatoire non stéroïdien (AINS)", "Fièvre, douleurs, inflammation (dents, articulations, règles).", "À prendre pendant un repas. À éviter en cas d'ulcère ou de gastrite, d'asthme, de maladie rénale, de déshydratation, de grossesse avancée. Pas chez le nourrisson de moins de 3 mois.", "En cas de diarrhée ou vomissements, ne pas donner d'AINS : risque pour les reins."),
    Fiche("Aspirine (acide acétylsalicylique)", "Antalgique, antipyrétique, antiagrégant", "Douleurs et fièvre chez l'adulte.", "Déconseillée chez l'enfant et l'adolescent en cas de fièvre ou de virose (risque de syndrome de Reye). Risque de saignement et d'ulcère. À éviter en fin de grossesse.", "En cas de doute chez l'enfant, choisir le paracétamol."),
    Fiche("Diclofénac", "Anti-inflammatoire non stéroïdien (AINS)", "Douleurs inflammatoires : articulations, dos, suites de traumatisme.", "Mêmes précautions que l'ibuprofène : estomac, reins, grossesse, asthme. Éviter chez les personnes ayant une maladie du cœur grave.", "Courte durée de traitement, toujours pendant un repas."),
  ]),
  ThemeSante("rhume", "Rhume, toux et gorge", Icons.air, Color(0xFF1565C0), "Rhume, grippe, mal de gorge et la plupart des toux sont causés par des virus : ils guérissent seuls en quelques jours. Les antibiotiques n'agissent pas sur les virus. On soulage les signes : nez bouché, fièvre, toux.", [
    "Respiration rapide, difficile, tirage entre les côtes ou sifflement",
    "Toux depuis plus de 2 semaines",
    "Fièvre élevée qui dure plus de 3 jours",
    "Enfant qui refuse de boire ou de téter, très abattu",
  ], [
    Fiche("Sérum physiologique (chlorure de sodium 0,9 %)", "Solution de lavage", "Lavage du nez (surtout chez le nourrisson), des yeux, nettoyage des plaies.", "Utiliser une unidose neuve à chaque lavage. Pas de réutilisation d'une ampoule ouverte.", "Le lavage du nez avant les repas et le coucher aide beaucoup l'enfant enrhumé."),
    Fiche("Chlorphénamine", "Antihistaminique sédatif", "Écoulement nasal, éternuements, démangeaisons allergiques.", "Provoque de la somnolence et la bouche sèche. Éviter l'alcool et la conduite. Déconseillé chez le très jeune enfant, glaucome, difficultés à uriner.", "À prendre plutôt le soir."),
    Fiche("Ambroxol ou carbocistéine", "Mucolytique (fluidifiant des sécrétions)", "Toux grasse avec sécrétions épaisses.", "Déconseillés chez le nourrisson de moins de 2 ans (risque d'encombrement). Éviter si ulcère. Bien boire de l'eau.", "Ne pas associer avec un antitussif qui bloque la toux."),
    Fiche("Dextrométhorphane", "Antitussif", "Toux sèche qui fatigue, sans sécrétions.", "Déconseillé chez l'enfant de moins de 6 ans. Ne pas associer avec certains antidépresseurs. Ne pas utiliser en cas de toux grasse.", "Si la toux dure plus de quelques jours, consulter."),
    Fiche("Pseudoéphédrine (décongestionnant)", "Décongestionnant par voie orale", "Nez bouché intense.", "Peut augmenter la tension artérielle et le rythme cardiaque. À éviter chez l'hypertendu, le cardiaque, l'enfant et la femme enceinte.", "Privilégier le lavage du nez au sérum physiologique."),
  ]),
  ThemeSante("ulcere", "Ulcère et acidité", Icons.local_fire_department, Color(0xFF6A1B9A), "Brûlures d'estomac, douleurs qui reviennent à jeun ou la nuit, ballonnements. Causes fréquentes : bactérie Helicobacter pylori, anti-inflammatoires, alcool, tabac, stress. Conseils : repas réguliers, éviter les aliments très épicés, ne pas prendre d'AINS sans nécessité.", [
    "Vomissement de sang ou selles noires",
    "Douleur très forte et brutale du ventre",
    "Amaigrissement, difficulté à avaler, vomissements répétés",
    "Brûlures qui durent plus de 2 semaines malgré le traitement",
  ], [
    Fiche("Oméprazole", "Inhibiteur de la pompe à protons (IPP)", "Ulcère gastro-duodénal, reflux, protection de l'estomac lors des traitements par AINS.", "À prendre le matin avant le repas, la gélule avalée entière. Effets possibles : maux de tête, diarrhée. Un traitement prolongé se fait sous surveillance.", "Les symptômes qui reviennent dès l'arrêt doivent amener à consulter."),
    Fiche("Pantoprazole", "Inhibiteur de la pompe à protons (IPP)", "Mêmes indications que l'oméprazole.", "Comprimé gastro-résistant à avaler entier avant le repas.", "Ne pas écraser ni croquer le comprimé."),
    Fiche("Hydroxyde d'aluminium + hydroxyde de magnésium", "Antiacide (pansement gastrique)", "Soulage rapidement les brûlures et les aigreurs.", "Peut gêner l'absorption d'autres médicaments : les prendre à 2 heures d'écart. Le magnésium peut donner la diarrhée, l'aluminium la constipation. Prudence en cas de maladie des reins.", "À prendre après les repas et au coucher."),
    Fiche("Trithérapie d'éradication d'Helicobacter pylori", "Association : IPP + deux antibiotiques", "Traitement prescrit lorsque l'ulcère est lié à la bactérie H. pylori (durée de 7 à 14 jours selon protocole).", "Uniquement sur ordonnance. Il faut suivre le traitement jusqu'au bout pour éradiquer la bactérie. Les antibiotiques peuvent donner nausées et diarrhée.", "Éviter l'alcool avec le métronidazole."),
  ]),
  ThemeSante("diarrhee", "Diarrhée et déshydratation", Icons.water_drop, Color(0xFF00838F), "Le danger de la diarrhée, c'est la déshydratation, surtout chez le nourrisson et le jeune enfant. Le traitement de base : boire beaucoup, continuer l'alimentation et l'allaitement, et donner la solution de réhydratation (SRO) et le zinc chez l'enfant. Les antibiotiques ne sont utiles que dans des cas précis.", [
    "Yeux enfoncés, bouche très sèche, pas de larmes, pli de peau qui reste marqué",
    "Enfant très abattu, qui ne boit pas ou vomit tout",
    "Présence de sang dans les selles",
    "Diarrhée chez un nourrisson de moins de 6 mois, ou qui dure plus de 14 jours",
  ], [
    Fiche("Sels de réhydratation orale (SRO)", "Solution de réhydratation", "Prévention et traitement de la déshydratation lors de diarrhées ou de vomissements.", "Dissoudre un sachet dans le volume d'eau potable indiqué sur le sachet, ni plus ni moins. Ne pas ajouter de sucre. Jeter la solution préparée après 24 heures.", "Donner à la cuillère ou par petites gorgées fréquentes. Si l'enfant vomit, attendre 10 minutes puis reprendre plus lentement."),
    Fiche("Zinc (comprimé dispersible)", "Oligo-élément", "Diarrhée de l'enfant de moins de 5 ans : réduit la durée et le risque de récidive.", "Cure d'environ 10 à 14 jours, même si la diarrhée s'arrête avant. Dose selon l'âge : voir la notice et le protocole national. Peut provoquer des vomissements : donner en petites quantités.", "À donner en plus du SRO, pas à la place."),
    Fiche("Lopéramide", "Antidiarrhéique (ralentit le transit)", "Diarrhée aiguë simple de l'adulte.", "Interdit chez l'enfant de moins de 2 ans. Ne pas utiliser en cas de fièvre élevée ou de sang dans les selles. Ne pas dépasser la dose maximale.", "Ne dispense jamais de boire et de se réhydrater."),
    Fiche("Métronidazole", "Antibiotique et antiparasitaire", "Amibiase, giardiase et certaines infections intestinales, sur prescription.", "Pas d'alcool pendant le traitement et 48 heures après. Goût métallique, nausées. Prudence au premier trimestre de grossesse.", "Prendre pendant ou après les repas."),
    Fiche("Racécadotril", "Antisécrétoire intestinal", "Diarrhée aiguë de l'enfant à partir de 3 mois, associé à la réhydratation.", "Ne remplace pas le SRO. Pas en cas de diarrhée sanglante ou avec fièvre importante.", "Poudre à mélanger dans de l'eau ou de la nourriture."),
  ]),
  ThemeSante("antibio", "Antibiotiques", Icons.science, Color(0xFF2E7D32), "Les antibiotiques tuent les bactéries, pas les virus. Ils sont donnés sur ordonnance, à la bonne dose et pendant toute la durée prescrite. Un traitement arrêté trop tôt ou pris sans nécessité favorise les résistances.", [
    "Éruption, gonflement du visage, gêne pour respirer après la prise : allergie, arrêter et aller aux urgences",
    "Diarrhée sévère ou sanglante pendant ou après un antibiotique",
    "Aucune amélioration au bout de 48 à 72 heures",
  ], [
    Fiche("Amoxicilline", "Pénicilline", "Angine bactérienne, otite, infections respiratoires et urinaires, selon prescription.", "Interdite en cas d'allergie aux pénicillines. Peut donner de la diarrhée ou une éruption. Durée complète du traitement.", "Prendre à intervalles réguliers, au début d'un repas ou à distance."),
    Fiche("Amoxicilline + acide clavulanique", "Pénicilline associée à un inhibiteur", "Infections plus résistantes (sinusite, otite, infections de la peau), sur prescription.", "Mêmes précautions que l'amoxicilline. Prendre au début d'un repas pour limiter les troubles digestifs.", "Ne pas la remplacer par l'amoxicilline simple sans avis."),
    Fiche("Cotrimoxazole (sulfaméthoxazole + triméthoprime)", "Sulfamide associé", "Infections urinaires et respiratoires, diarrhées infectieuses, prévention de certaines infections chez les personnes vivant avec le VIH.", "Contre-indiqué en cas d'allergie aux sulfamides, chez le nouveau-né et au premier trimestre de grossesse. Bien boire pendant le traitement. Éruption : arrêter et consulter.", "Ne pas associer avec la sulfadoxine-pyriméthamine."),
    Fiche("Azithromycine", "Macrolide", "Infections respiratoires, de la gorge, de la peau ; certaines infections sexuellement transmissibles.", "Peut allonger l'intervalle QT. Prendre à distance des antiacides. Courte durée : respecter exactement la dose.", "Se prend en une prise par jour."),
    Fiche("Doxycycline", "Cycline", "Infections respiratoires, brucellose, rickettsioses, selon prescription.", "Interdite chez la femme enceinte et l'enfant de moins de 8 ans (taches sur les dents). Sensibilise la peau au soleil. Prendre avec un grand verre d'eau, assis, à distance des produits laitiers.", "Ne pas s'allonger juste après la prise."),
    Fiche("Ciprofloxacine", "Fluoroquinolone", "Infections urinaires, certaines diarrhées bactériennes sévères (adulte), selon prescription.", "Risque de tendinite. Éviter chez l'enfant, la femme enceinte et en cas d'épilepsie, sauf avis médical. À distance des antiacides et des produits laitiers.", "Antibiotique à réserver : ne pas l'utiliser pour les infections banales."),
    Fiche("Ceftriaxone et gentamicine injectables", "Céphalosporine et aminoside", "Infections graves (méningite, septicémie, pneumonie sévère), en structure de santé.", "Réservés au personnel de santé. Gentamicine : surveiller les reins et l'audition. Ceftriaxone : pas de mélange avec le calcium chez le nouveau-né.", "Un malade grave doit être transféré rapidement."),
  ]),
  ThemeSante("vers", "Vers intestinaux et bilharziose", Icons.pest_control, Color(0xFF8D6E63), "Les vers intestinaux causent douleurs, anémie, retard de croissance chez l'enfant. Prévention : se laver les mains, boire de l'eau propre, porter des chaussures, utiliser des latrines. Le déparasitage de masse se fait régulièrement selon les programmes nationaux.", [
    "Anémie sévère, ventre très gonflé, vomissement de vers",
    "Sang dans les urines (bilharziose)",
    "Douleur abdominale intense avec arrêt des selles",
  ], [
    Fiche("Albendazole", "Antiparasitaire (vermifuge)", "Ascaris, ankylostomes, trichocéphales et autres vers intestinaux. Souvent en une prise unique.", "Déconseillé au premier trimestre de grossesse. Chez l'enfant, pas avant l'âge indiqué sur la notice (le plus souvent 1 an). À prendre avec un repas.", "Recommencer la cure tous les 6 mois dans les zones concernées."),
    Fiche("Mébendazole", "Antiparasitaire (vermifuge)", "Vers intestinaux, une prise ou une cure courte selon le schéma.", "Pas chez le nourrisson de moins de 1 an ni la femme enceinte au premier trimestre.", "Mâcher le comprimé ou l'écraser chez le petit enfant."),
    Fiche("Praziquantel", "Antiparasitaire", "Bilharziose (schistosomiase), en dose unique adaptée au poids.", "Peut donner vertiges, maux de ventre. À prendre avec un repas. Dose selon le poids : protocole du programme de lutte.", "Éviter de se baigner dans les eaux stagnantes."),
    Fiche("Ivermectine", "Antiparasitaire", "Gale, onchocercose, strongyloïdose, selon protocole.", "Pas chez la femme enceinte et l'enfant de petit poids (en général moins de 15 kg). Avis médical en zone de loase.", "Traiter aussi l'entourage proche en cas de gale."),
  ]),
  ThemeSante("allergie", "Allergies et démangeaisons", Icons.healing, Color(0xFFAD1457), "Rhinite allergique, urticaire, piqûres d'insectes, eczéma. Les antihistaminiques soulagent les démangeaisons ; les crèmes à base de corticoïdes traitent l'inflammation locale. On cherche et on évite la cause quand elle est connue.", [
    "Gonflement des lèvres, de la langue ou de la gorge, gêne pour respirer",
    "Malaise brutal après une piqûre, un médicament ou un aliment : urgence vitale, appeler les secours",
    "Éruption avec fièvre ou qui s'étend très vite",
  ], [
    Fiche("Cétirizine", "Antihistaminique de 2e génération", "Rhume des foins, urticaire, démangeaisons allergiques. Une prise par jour.", "Peut donner une légère somnolence. Adapter la dose en cas de maladie des reins. Pas chez le petit enfant de moins de 2 ans sans avis médical.", "À prendre le soir si elle endort."),
    Fiche("Loratadine", "Antihistaminique de 2e génération", "Mêmes indications que la cétirizine, peu sédatif.", "Dose selon l'âge ou le poids chez l'enfant. Prudence en cas de maladie du foie.", "Une prise par jour, avec ou sans repas."),
    Fiche("Hydrocortisone en crème (dermocorticoïde)", "Corticoïde local", "Eczéma, piqûres, dermatoses inflammatoires, en cure courte.", "Pas sur une plaie infectée, un herpès ou de la gale. Sur le visage et chez l'enfant : courte durée et petite quantité. Ne pas appliquer en pansement fermé.", "Arrêter progressivement selon l'avis du médecin."),
    Fiche("Calamine (lotion)", "Calmant cutané", "Soulage les démangeaisons, la varicelle, les piqûres.", "Usage externe uniquement. Bien agiter avant usage.", "Appliquer en couche fine avec du coton propre."),
  ]),
  ThemeSante("peau", "Peau, mycoses et gale", Icons.spa, Color(0xFF558B2F), "Teignes, mycoses, gale, impétigo et petites plaies sont très fréquents chez l'enfant. L'hygiène, le linge propre et le traitement de l'entourage sont aussi importants que les médicaments.", [
    "Plaie qui gonfle, chauffe, suppure ou s'accompagne de fièvre",
    "Rougeur qui s'étend rapidement",
    "Lésions sur tout le corps chez le nourrisson",
  ], [
    Fiche("Miconazole ou clotrimazole (crème)", "Antifongique local", "Mycoses de la peau, pied d'athlète, candidoses.", "Appliquer sur peau propre et sèche, 2 fois par jour, quelques jours après la disparition des lésions.", "Laver et sécher soigneusement les plis."),
    Fiche("Griséofulvine", "Antifongique par voie orale", "Teigne du cuir chevelu (traitement long, sur prescription).", "À prendre avec un repas gras. Traitement de plusieurs semaines. Déconseillée pendant la grossesse.", "Ne pas partager peignes, bonnets et serviettes."),
    Fiche("Benzoate de benzyle (lotion)", "Antiparasitaire local", "Gale : application sur tout le corps, du cou aux pieds, selon le schéma de la notice.", "Éviter les yeux et les muqueuses. Dilution adaptée chez l'enfant. Irritation possible.", "Traiter toute la famille en même temps et laver le linge à 60 °C ou l'exposer au soleil."),
    Fiche("Povidone iodée et chlorhexidine", "Antiseptiques", "Désinfection des plaies et de la peau avant un soin.", "Ne pas mélanger deux antiseptiques. Povidone iodée : prudence en cas d'allergie à l'iode, de maladie de la thyroïde, chez le nouveau-né. Ne jamais utiliser l'alcool dans une plaie profonde.", "Nettoyer d'abord à l'eau propre et au savon."),
  ]),
  ThemeSante("nutrition", "Nutrition, anémie et vitamines", Icons.restaurant, Color(0xFFF9A825), "L'anémie et la malnutrition touchent beaucoup d'enfants et de femmes enceintes. On associe une alimentation variée, la lutte contre le paludisme et les vers, et des compléments quand c'est nécessaire.", [
    "Pâleur importante, fatigue extrême, essoufflement",
    "Œdèmes des pieds, cheveux décolorés, enfant très maigre : malnutrition à faire évaluer au centre de santé",
    "Refus de manger, vomissements persistants chez un enfant malnutri",
  ], [
    Fiche("Fer + acide folique", "Antianémique", "Prévention et traitement de l'anémie, notamment pendant la grossesse.", "Provoque des selles noires et parfois constipation ou nausées. À prendre à distance du thé, du café et du lait. Garder hors de portée des enfants : le surdosage en fer est dangereux.", "Prendre avec un jus riche en vitamine C pour mieux absorber le fer."),
    Fiche("Vitamine A", "Vitamine", "Supplémentation périodique du jeune enfant selon le programme national, lutte contre la cécité nocturne.", "Ne pas répéter les doses sans consigne : le surdosage est toxique, surtout pendant la grossesse.", "Se donne lors des journées nationales et des consultations."),
    Fiche("Acide folique", "Vitamine B9", "Prévention de certaines malformations lors de la grossesse, anémie par carence.", "Poursuivre selon l'avis du médecin ou de la sage-femme.", "À commencer avant la grossesse si possible."),
    Fiche("Aliment thérapeutique prêt à l'emploi (ATPE)", "Aliment spécialisé, pas un médicament", "Prise en charge de la malnutrition aiguë sévère, sous suivi du centre de santé.", "Réservé à l'enfant malnutri. L'enfant doit aussi pouvoir boire de l'eau propre à volonté. Ne pas partager avec la fratrie.", "Ne pas le diluer dans l'eau."),
    Fiche("Multivitamines et vitamine C", "Compléments", "Compléments alimentaires, convalescence.", "Ne remplacent pas une alimentation variée. Respecter les doses.", "Conserver à l'abri de la chaleur."),
  ]),
  ThemeSante("chronique", "Tension et diabète (adultes)", Icons.monitor_heart, Color(0xFF3949AB), "L'hypertension et le diabète sont des maladies chroniques : le traitement dure toute la vie et ne doit jamais être arrêté sans avis. Mesures associées : moins de sel et de sucre, activité physique, suivi régulier.", [
    "Maux de tête violents, troubles de la vue ou de la parole, faiblesse d'un côté du corps",
    "Douleur à la poitrine",
    "Sueurs, tremblements, confusion : possible hypoglycémie, donner du sucre si le malade est conscient",
    "Soif intense, vomissements, haleine acétonique",
  ], [
    Fiche("Amlodipine", "Inhibiteur calcique", "Hypertension artérielle, une prise par jour.", "Peut donner des gonflements des chevilles, des maux de tête et un visage rouge.", "Prendre à heure fixe, même si la tension est normale."),
    Fiche("Captopril ou énalapril", "Inhibiteur de l'enzyme de conversion (IEC)", "Hypertension artérielle et insuffisance cardiaque.", "Interdits pendant la grossesse. Toux sèche fréquente. Surveiller les reins et le potassium.", "Boire suffisamment et signaler un gonflement du visage."),
    Fiche("Hydrochlorothiazide", "Diurétique", "Hypertension artérielle.", "Augmente les urines, peut faire baisser le potassium. Prudence en cas de diabète et de goutte.", "À prendre le matin."),
    Fiche("Metformine", "Antidiabétique oral", "Diabète de type 2.", "À prendre pendant les repas. Arrêt temporaire en cas de vomissements, de déshydratation ou d'examen avec produit de contraste. Contre-indiquée en cas de maladie grave des reins.", "Les troubles digestifs diminuent le plus souvent après quelques jours."),
    Fiche("Glibenclamide", "Sulfamide hypoglycémiant", "Diabète de type 2.", "Risque d'hypoglycémie, surtout si le repas est sauté. Prudence chez la personne âgée.", "Toujours avoir du sucre sur soi."),
    Fiche("Insuline", "Hormone", "Diabète de type 1 et certains cas de type 2, sur prescription.", "Conserver le stylo ou le flacon non entamé au frais, à l'abri de la chaleur. Changer le site d'injection à chaque fois. Respecter les doses.", "Apprendre à reconnaître et à corriger l'hypoglycémie."),
  ]),
  ThemeSante("soins", "Plaies, yeux et oreilles", Icons.healing, Color(0xFF00695C), "Les petits soins du quotidien : nettoyer, protéger, éviter l'infection. Une bonne technique de lavage des mains et du matériel propre sont déjà la moitié du traitement.", [
    "Plaie profonde, morsure ou plaie souillée de terre : penser au vaccin antitétanique",
    "Œil rouge avec douleur, baisse de la vue ou pus abondant",
    "Écoulement de l'oreille avec fièvre ou douleur intense",
  ], [
    Fiche("Compresses stériles, bandes et sparadrap", "Matériel de pansement", "Protéger les plaies après nettoyage.", "Ouvrir l'emballage juste avant l'emploi. Changer le pansement s'il est mouillé ou souillé.", "Se laver les mains avant chaque pansement."),
    Fiche("Pommade ophtalmique à la tétracycline", "Antibiotique local pour l'œil", "Conjonctivite bactérienne, prévention chez le nouveau-né selon protocole.", "Ne pas toucher l'œil avec l'embout du tube. Un tube par patient. Pas de port de lentilles pendant le traitement.", "Laver l'œil au sérum physiologique avant d'appliquer."),
    Fiche("Collyre au chloramphénicol", "Antibiotique local pour l'œil", "Conjonctivite bactérienne, selon prescription.", "Respecter la durée prescrite. Éviter l'usage répété sans avis.", "Jeter le flacon 15 jours après ouverture si la notice le demande."),
    Fiche("Sérum antitétanique et vaccin antitétanique", "Prévention du tétanos", "Prévention du tétanos après une plaie à risque, selon le statut vaccinal.", "Réservés au personnel de santé. Se renseigner sur les vaccinations déjà reçues.", "Pensez à la mise à jour des vaccins après un accident."),
  ]),
];
