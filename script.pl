#!/usr/bin/perl
use strict;
use warnings;
use Text::ParseWords;
use File::Path qw(make_path);
use POSIX qw(strftime);

# Dossier de résultats
my $RESULT_DIR = "RESULTAT";
make_path($RESULT_DIR);  # Crée le dossier RESULTAT s'il n'existe pas

# Chemins relatifs des fichiers CSV
my $BIENS_RISQUES_CSV = "./Library/Ressources/BIENS_RISQUES.csv";
my $RISQUES_ATTAQUES_CSV = "./Library/Ressources/RISQUES_ATTAQUES.csv";
my $ATTAQUES_OUTILS_CSV = "./Library/Ressources/ATTAQUES_OUTILS.csv";  # Correction du nom du fichier

# Fonction pour demander des informations à l'utilisateur
sub ask_for_info {
    print "Entrez votre nom et prénom (testeur): ";
    my $tester = <STDIN>;
    chomp($tester);

    print "Entrez le nom du client ou de l'organisation: ";
    my $client = <STDIN>;
    chomp($client);

    my $date_test = strftime("%d/%m/%Y", localtime);  # Date du jour au format JJ/MM/AAAA

    return ($tester, $client, $date_test);
}

# Fonction pour lire un fichier CSV
sub read_csv {
    my ($file) = @_;
    open(my $fh, "<", $file) or die "Impossible d'ouvrir $file: $!";
    my @rows;
    while (my $line = <$fh>) {
        chomp($line);
        push @rows, [parse_line(',', 0, $line)];
    }
    close($fh);
    return \@rows;
}

# Fonction pour sélectionner un bien essentiel
sub select_bien_essentiel {
    my $biens_risques = read_csv($BIENS_RISQUES_CSV);
    print "Liste des biens essentiels disponibles :\n";
    for (my $i = 1; $i < scalar(@$biens_risques); $i++) {
        print "$i. " . $biens_risques->[$i][0] . "\n";
    }
    print "Sélectionnez un bien essentiel (numéro): ";
    my $bien_num = <STDIN>;
    chomp($bien_num);
    my $bien = $biens_risques->[$bien_num][0];
    print "Bien essentiel sélectionné : $bien\n";
    return $bien;
}

# Fonction pour associer un risque à un bien essentiel
sub associer_risque {
    my ($bien) = @_;
    my $biens_risques = read_csv($BIENS_RISQUES_CSV);
    for my $row (@$biens_risques) {
        if ($row->[0] eq $bien) {
            my $risque = $row->[1];
            print "Risque associé : $risque\n";
            return $risque;
        }
    }
    die "Risque non trouvé pour le bien $bien";
}

# Fonction pour associer une attaque à un risque
sub associer_attaque {
    my ($risque) = @_;
    my $risques_attaques = read_csv($RISQUES_ATTAQUES_CSV);
    for my $row (@$risques_attaques) {
        if ($row->[0] eq $risque) {
            my $attaque = $row->[1];
            print "Attaque associée : $attaque\n";
            return $attaque;
        }
    }
    die "Attaque non trouvée pour le risque $risque";
}

# Fonction pour associer un outil à une attaque
#sub associer_outil {
#    my ($attaque) = @_;
#    my $attaques_outils = read_csv($ATTAQUES_OUTILS_CSV);
#    for my $row (@$attaques_outils) {
#        if ($row->[0] eq $attaque) {
#            my $outil = $row->[1];
#            print "Outil associé : $outil\n";
#            return $outil;
#        }
#    }
#    die "Outil non trouvé pour l'attaque $attaque";
#}
# Fonction pour associer un outil à une attaque
sub associer_outil {
    my ($attaque) = @_;
    my $attaques_outils = read_csv($ATTAQUES_OUTILS_CSV);
    my @outils;

    # Récupérer tous les outils associés à l'attaque
    for my $row (@$attaques_outils) {
        if ($row->[0] eq $attaque) {
            push @outils, $row->[1];
        }
    }

    if (!@outils) {
        die "Aucun outil trouvé pour l'attaque $attaque";
    }

    # Afficher les outils disponibles
    print "Outils disponibles pour l'attaque '$attaque' :\n";
    for (my $i = 0; $i < @outils; $i++) {
        print "$i. $outils[$i]\n";
    }

    # Demander à l'utilisateur de choisir
    print "Sélectionnez un outil (numéro) : ";
    my $choix = <STDIN>;
    chomp($choix);

    my $outil = $outils[$choix];
    print "Outil sélectionné : $outil\n";
    return $outil;
}

# Fonction pour vérifier si l'outil est installé
sub check_tool_installed {
    my ($outil) = @_;
    if (system("which $outil > /dev/null 2>&1") != 0) {
        print "L'outil $outil n'est pas installé.\n";
        print "Voulez-vous l'installer maintenant ? (o/n): ";
        my $response = <STDIN>;
        chomp($response);
        if ($response eq 'o' || $response eq 'O') {
            print "Installation de $outil...\n";
            system("sudo apt-get install -y $outil");
            if ($? == 0) {
                print "$outil a été installé avec succès.\n";
            } else {
                die "Échec de l'installation de $outil. Veuillez l'installer manuellement.";
            }
        } else {
            die "L'outil $outil est requis pour continuer.";
        }
    }
    print "L'outil $outil est installé.\n";
}

# Fonction pour exécuter l'outil
sub run_tool {
    my ($outil) = @_;
    print "Entrez la cible à tester (IP ou URL): ";
    my $target = <STDIN>;
    chomp($target);
    print "Exécution de $outil sur $target...\n";
    my $result = `$outil $target`;
    print "$result\n";
    return $result;
}

# Fonction pour demander un commentaire
sub ask_for_comment {
    print "Entrez un commentaire sur les résultats: ";
    my $comment = <STDIN>;
    chomp($comment);
    return $comment;
}

# Fonction pour générer le rapport en Markdown
sub generate_report {
    my ($tester, $client, $date_test, $bien, $risque, $attaque, $outil, $result, $comment) = @_;
    my $report_file = "$RESULT_DIR/rapport_" . strftime("%Y%m%d_%H%M%S", localtime) . "_" . $client . ".md";
    open(my $fh, ">", $report_file) or die "Impossible de créer le rapport : $!";
    print $fh "# Rapport de Test de Sécurité\n";
    print $fh "## Informations Générales\n";
    print $fh "- **Date du test** : $date_test\n";
    print $fh "- **Testeur** : $tester\n";
    print $fh "- **Client** : $client\n";
    print $fh "---\n";
    print $fh "## Bien Essentiel Testé\n";
    print $fh "- **Bien essentiel** : $bien\n";
    print $fh "- **Risque associé** : $risque\n";
    print $fh "- **Attaque associée** : $attaque\n";
    print $fh "- **Outil utilisé** : $outil\n";
    print $fh "---\n";
    print $fh "## Résultats du Test\n";
    print $fh "```\n";
    print $fh "$result\n";
    print $fh "```\n";
    print $fh "---\n";
    print $fh "## Commentaires\n";
    print $fh "$comment\n";
    print $fh "---\n";
    print $fh "## Conclusion\n";
    print $fh "Le test a été réalisé avec succès. Les résultats sont disponibles ci-dessus.\n";
    close($fh);
    print "Rapport généré avec succès : $report_file\n";
}

# Fonction principale
sub main {
    my ($tester, $client, $date_test) = ask_for_info();
    my $bien = select_bien_essentiel();
    my $risque = associer_risque($bien);
    my $attaque = associer_attaque($risque);
    my $outil = associer_outil($attaque);
    check_tool_installed($outil);
    my $result = run_tool($outil);
    my $comment = ask_for_comment();
    generate_report($tester, $client, $date_test, $bien, $risque, $attaque, $outil, $result, $comment);
}

# Exécution du script
main();
