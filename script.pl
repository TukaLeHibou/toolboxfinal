#!/usr/bin/perl
use strict;
use warnings;
use Text::ParseWords;
use File::Path qw(make_path);
use POSIX qw(strftime);
use File::Spec;
use Cwd 'abs_path';
use Term::ANSIColor;
use Getopt::Long;
use Pod::Usage;
use File::Find;

# Configuration globale
my $VERSION = "2.0.0";
my $RESULT_DIR = "RESULTAT";
my $LOG_DIR = "LOGS";
my $LIBRARY_DIR = "./Library";
my $VULNOSI_DIR = "$LIBRARY_DIR/VulnOSI";
my $TIMEOUT = 300; # 5 minutes par défaut
my $DEBUG = 0;
my $DRY_RUN = 0;

# Initialisation des options en ligne de commande
GetOptions(
    'help|h'     => sub { pod2usage(1) },
    'version|v'  => sub { print "Script version $VERSION\n"; exit 0 },
    'debug|d'    => \$DEBUG,
    'dry-run'    => \$DRY_RUN,
    'timeout=i'  => \$TIMEOUT,
) or pod2usage(2);

# Création des dossiers nécessaires
make_path($RESULT_DIR, $LOG_DIR);

# Chemins relatifs sécurisés
my %CSV_FILES = (
    'biens_risques'   => "$LIBRARY_DIR/Ressources/BIENS_RISQUES.csv",
    'risques_attaques' => "$LIBRARY_DIR/Ressources/RISQUES_ATTAQUES.csv",  
    'attaques_outils' => "$LIBRARY_DIR/Ressources/ATTAQUES_OUTILS.csv"
);

# Fonction de logging avec couleurs
sub log_message {
    my ($level, $message) = @_;
    my $timestamp = strftime("%Y-%m-%d %H:%M:%S", localtime);
    my $log_file = "$LOG_DIR/script_" . strftime("%Y%m%d", localtime) . ".log";
    
    my %colors = (
        'INFO'  => 'green',
        'WARN'  => 'yellow', 
        'ERROR' => 'red',
        'DEBUG' => 'cyan'
    );
    
    my $colored_message = colored("[$timestamp] [$level] $message", $colors{$level} || 'white');
    print "$colored_message\n" if $level ne 'DEBUG' || $DEBUG;
    
    # Écriture dans le fichier de log
    if (open(my $log_fh, ">>", $log_file)) {
        print $log_fh "[$timestamp] [$level] $message\n";
        close($log_fh);
    }
}

# Validation sécurisée des entrées
sub validate_input {
    my ($input, $type) = @_;
    
    return 0 unless defined $input && length($input) > 0;
    
    my %patterns = (
        'name' => qr/^[\w\s\-\.àâäçéèêëïîôùûüÿñæœ]{1,100}$/i,
        'client' => qr/^[\w\s\-\.àâäçéèêëïîôùûüÿñæœ]{1,100}$/i,
        'ip' => qr/^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/,
        'url' => qr/^https?:\/\/[\w\.\-\/\?\&\=\:\@\%\#\+]+$/i,
        'domain' => qr/^[\w\.\-]+$/,
        'number' => qr/^\d+$/
    );
    
    return $input =~ $patterns{$type} if exists $patterns{$type};
    return 1; # Par défaut, accepter
}

# Fonction pour demander des informations à l'utilisateur avec validation
sub ask_for_info {
    my ($tester, $client, $date_test);
    
    do {
        print colored("Entrez votre nom et prénom (testeur): ", 'cyan');
        $tester = <STDIN>;
        chomp($tester);
        log_message('WARN', 'Nom du testeur invalide') unless validate_input($tester, 'name');
    } while (!validate_input($tester, 'name'));
    
    do {
        print colored("Entrez le nom du client ou de l'organisation: ", 'cyan');
        $client = <STDIN>;
        chomp($client);
        log_message('WARN', 'Nom du client invalide') unless validate_input($client, 'client');
    } while (!validate_input($client, 'client'));

    $date_test = strftime("%d/%m/%Y", localtime);
    log_message('INFO', "Informations collectées - Testeur: $tester, Client: $client");
    
    return ($tester, $client, $date_test);
}

# Fonction pour lire un fichier CSV avec gestion d'erreurs
sub read_csv {
    my ($file) = @_;
    
    unless (-f $file && -r $file) {
        log_message('ERROR', "Fichier CSV non accessible: $file");
        die "Fichier CSV non accessible: $file";
    }
    
    open(my $fh, "<:encoding(utf8)", $file) or do {
        log_message('ERROR', "Impossible d'ouvrir $file: $!");
        die "Impossible d'ouvrir $file: $!";
    };
    
    my @rows;
    my $line_num = 0;
    
    while (my $line = <$fh>) {
        $line_num++;
        chomp($line);
        next if $line =~ /^#/ || $line =~ /^\s*$/; # Ignorer commentaires et lignes vides
        
        my @fields = parse_line(',', 0, $line);
        if (@fields >= 2) {
            push @rows, \@fields;
        } else {
            log_message('WARN', "Ligne $line_num malformée dans $file: $line");
        }
    }
    close($fh);
    
    log_message('DEBUG', "Lu " . scalar(@rows) . " lignes de $file");
    return \@rows;
}

# Fonction pour sélectionner un bien essentiel
sub select_bien_essentiel {
    my $biens_risques = read_csv($CSV_FILES{'biens_risques'});
    
    print colored("\n=== Liste des biens essentiels disponibles ===\n", 'bold yellow');
    
    my @biens_uniques;
    my %seen;
    
    for my $row (@$biens_risques) {
        next if $seen{$row->[0]}++;
        push @biens_uniques, $row->[0];
    }
    
    for (my $i = 0; $i < @biens_uniques; $i++) {
        print colored(($i + 1) . ". " . $biens_uniques[$i] . "\n", 'white');
    }
    
    my $bien_num;
    do {
        print colored("Sélectionnez un bien essentiel (numéro 1-" . @biens_uniques . "): ", 'cyan');
        $bien_num = <STDIN>;
        chomp($bien_num);
        
        unless (validate_input($bien_num, 'number') && $bien_num >= 1 && $bien_num <= @biens_uniques) {
            log_message('WARN', 'Sélection invalide pour bien essentiel');
            print colored("Sélection invalide. Veuillez choisir un numéro entre 1 et " . @biens_uniques . "\n", 'red');
        }
    } while (!validate_input($bien_num, 'number') || $bien_num < 1 || $bien_num > @biens_uniques);
    
    my $bien = $biens_uniques[$bien_num - 1];
    log_message('INFO', "Bien essentiel sélectionné: $bien");
    print colored(" Bien essentiel sélectionné : $bien\n", 'green');
    
    return $bien;
}

# Fonction pour associer un risque à un bien essentiel
sub associer_risque {
    my ($bien) = @_;
    my $biens_risques = read_csv($CSV_FILES{'biens_risques'});
    
    for my $row (@$biens_risques) {
        if ($row->[0] eq $bien) {
            my $risque = $row->[1];
            log_message('INFO', "Risque associé trouvé: $risque");
            print colored(" Risque associé : $risque\n", 'green');
            return $risque;
        }
    }
    
    log_message('ERROR', "Risque non trouvé pour le bien: $bien");
    die "Risque non trouvé pour le bien $bien";
}

# Fonction pour associer une attaque à un risque
sub associer_attaque {
    my ($risque) = @_;
    my $risques_attaques = read_csv($CSV_FILES{'risques_attaques'});
    
    for my $row (@$risques_attaques) {
        if ($row->[0] eq $risque) {
            my $attaque = $row->[1];
            log_message('INFO', "Attaque associée trouvée: $attaque");
            print colored(" Attaque associée : $attaque\n", 'green');
            return $attaque;
        }
    }
    
    log_message('ERROR', "Attaque non trouvée pour le risque: $risque");
    die "Attaque non trouvée pour le risque $risque";
}

# Fonction pour associer un outil à une attaque avec choix multiple
sub associer_outil {
    my ($attaque) = @_;
    my $attaques_outils = read_csv($CSV_FILES{'attaques_outils'});
    my @outils;

    # Récupérer tous les outils associés à l'attaque
    for my $row (@$attaques_outils) {
        if ($row->[0] eq $attaque) {
            push @outils, $row->[1];
        }
    }

    unless (@outils) {
        log_message('ERROR', "Aucun outil trouvé pour l'attaque: $attaque");
        die "Aucun outil trouvé pour l'attaque $attaque";
    }

    if (@outils == 1) {
        log_message('INFO', "Outil unique trouvé: $outils[0]");
        print colored(" Outil sélectionné : $outils[0]\n", 'green');
        return $outils[0];
    }

    # Afficher les outils disponibles
    print colored("\n=== Outils disponibles pour l'attaque '$attaque' ===\n", 'bold yellow');
    for (my $i = 0; $i < @outils; $i++) {
        print colored(($i + 1) . ". $outils[$i]\n", 'white');
    }

    my $choix;
    do {
        print colored("Sélectionnez un outil (numéro 1-" . @outils . ") : ", 'cyan');
        $choix = <STDIN>;
        chomp($choix);
        
        unless (validate_input($choix, 'number') && $choix >= 1 && $choix <= @outils) {
            log_message('WARN', 'Sélection d\'outil invalide');
            print colored("Sélection invalide. Veuillez choisir un numéro entre 1 et " . @outils . "\n", 'red');
        }
    } while (!validate_input($choix, 'number') || $choix < 1 || $choix > @outils);

    my $outil = $outils[$choix - 1];
    log_message('INFO', "Outil sélectionné: $outil");
    print colored(" Outil sélectionné : $outil\n", 'green');
    
    return $outil;
}

# Fonction pour charger la configuration d'un outil depuis VulnOSI
sub load_tool_config {
    my ($outil) = @_;
    
    # Chercher le fichier de l'outil dans tous les niveaux OSI
    my $tool_file;
    
    for my $level (1..7) {
        my $potential_file = "$VULNOSI_DIR/level$level/$outil.md";
        if (-f $potential_file) {
            $tool_file = $potential_file;
            last;
        }
    }
    
    unless ($tool_file) {
        log_message('ERROR', "Fichier de configuration non trouvé pour l'outil: $outil");
        die "Fichier de configuration non trouvé pour l'outil $outil";
    }
    
    log_message('DEBUG', "Chargement de la configuration depuis: $tool_file");
    
    open(my $fh, "<:encoding(utf8)", $tool_file) or do {
        log_message('ERROR', "Impossible d'ouvrir $tool_file: $!");
        die "Impossible d'ouvrir $tool_file: $!";
    };
    
    my %config;
    my $current_section = '';
    
    while (my $line = <$fh>) {
        chomp($line);
        
        if ($line =~ /^# PRE_REQUIS_EXEC$/) {
            $current_section = 'prereq';
            next;
        } elsif ($line =~ /^# COMMANDE_EXEC$/) {
            $current_section = 'command';
            next;
        } elsif ($line =~ /^#/ || $line =~ /^\s*$/) {
            $current_section = '' unless $line =~ /^# (PRE_REQUIS_EXEC|COMMANDE_EXEC)$/;
            next;
        }
        
        if ($current_section eq 'prereq') {
            $config{'prereq'} = $line;
        } elsif ($current_section eq 'command') {
            $config{'command'} = $line;
        }
    }
    close($fh);
    
    log_message('DEBUG', "Configuration chargée pour $outil: " . join(', ', keys %config));
    return \%config;
}

# Fonction pour vérifier si l'outil est installé
sub check_tool_installed {
    my ($outil) = @_;
    
    log_message('DEBUG', "Vérification de l'installation de: $outil");
    
    if (system("which $outil > /dev/null 2>&1") != 0) {
        print colored(" L'outil $outil n'est pas installé.\n", 'yellow');
        
        if ($DRY_RUN) {
            print colored("[DRY-RUN] L'outil $outil serait installé\n", 'yellow');
            return;
        }
        
        print colored("Voulez-vous l'installer maintenant ? (o/n): ", 'cyan');
        my $response = <STDIN>;
        chomp($response);
        
        if ($response =~ /^[oO]$/) {
            my $config = load_tool_config($outil);
            
            if ($config->{'prereq'}) {
                print colored("Installation de $outil...\n", 'yellow');
                log_message('INFO', "Installation de $outil avec: $config->{'prereq'}");
                
                my $install_result = system($config->{'prereq'});
                if ($install_result == 0) {
                    log_message('INFO', "$outil installé avec succès");
                    print colored(" $outil a été installé avec succès.\n", 'green');
                } else {
                    log_message('ERROR', "Échec de l'installation de $outil");
                    die "Échec de l'installation de $outil. Veuillez l'installer manuellement.";
                }
            } else {
                log_message('WARN', "Pas de commande d'installation trouvée pour $outil");
                print colored(" Pas de commande d'installation automatique trouvée pour $outil\n", 'yellow');
                print colored("Veuillez l'installer manuellement.\n", 'yellow');
                return;
            }
        } else {
            log_message('WARN', "Installation de $outil refusée par l'utilisateur");
            die "L'outil $outil est requis pour continuer.";
        }
    } else {
        log_message('INFO', "L'outil $outil est déjà installé");
        print colored(" L'outil $outil est installé.\n", 'green');
    }
}

# Fonction pour valider et demander la cible
sub ask_for_target {
    my $target;
    
    do {
        print colored("Entrez la cible à tester (IP, domaine ou URL): ", 'cyan');
        $target = <STDIN>;
        chomp($target);
        
        # Validation basique de la cible
        unless (validate_input($target, 'ip') || 
                validate_input($target, 'domain') || 
                validate_input($target, 'url')) {
            log_message('WARN', 'Format de cible invalide');
            print colored("Format de cible invalide. Utilisez une IP, un domaine ou une URL valide.\n", 'red');
            $target = '';
        }
    } while (!$target);
    
    log_message('INFO', "Cible sélectionnée: $target");
    return $target;
}

# Fonction pour exécuter l'outil avec timeout et gestion d'erreurs
sub run_tool {
    my ($outil, $target) = @_;
    
    my $config = load_tool_config($outil);
    
    unless ($config->{'command'}) {
        log_message('ERROR', "Pas de commande trouvée pour l'outil: $outil");
        die "Pas de commande d'exécution trouvée pour l'outil $outil";
    }
    
    # Remplacer la variable TARGET dans la commande
    my $command = $config->{'command'};
    $command =~ s/\$TARGET/$target/g;
    $command =~ s/"\$TARGET"/"$target"/g;
    
    print colored("Exécution de $outil sur $target...\n", 'yellow');
    log_message('INFO', "Exécution de la commande: $command");
    
    if ($DRY_RUN) {
        print colored("[DRY-RUN] Commande qui serait exécutée: $command\n", 'yellow');
        return "Résultat simulé en mode dry-run";
    }
    
    # Exécution avec timeout
    my $result;
    eval {
        local $SIG{ALRM} = sub { die "timeout\n" };
        alarm $TIMEOUT;
        $result = `$command 2>&1`;
print $result;
        alarm 0;
    };
    
    if ($@ eq "timeout\n") {
        log_message('ERROR', "Timeout lors de l'exécution de $outil");
        die "Timeout lors de l'exécution de $outil (${TIMEOUT}s)";
    } elsif ($@) {
        log_message('ERROR', "Erreur lors de l'exécution: $@");
        die "Erreur lors de l'exécution: $@";
    }
    
    my $exit_code = $? >> 8;
    log_message('DEBUG', "Code de sortie: $exit_code");
    
    if ($exit_code != 0) {
        log_message('WARN', "L'outil $outil a retourné le code d'erreur: $exit_code");
        print colored(" L'outil a retourné le code d'erreur: $exit_code\n", 'yellow');
    }
    
    log_message('INFO', "Exécution de $outil terminée");
    print colored(" Exécution terminée\n", 'green');
    
    return $result || "Aucun résultat retourné par l'outil";
}

# Fonction pour demander un commentaire
sub ask_for_comment {
    print colored("Entrez un commentaire sur les résultats (optionnel): ", 'cyan');
    my $comment = <STDIN>;
    chomp($comment);
    
    $comment = "Aucun commentaire" if !$comment || $comment =~ /^\s*$/;
    log_message('DEBUG', "Commentaire saisi: $comment");
    
    return $comment;
}

# Fonction pour générer le rapport en Markdown amélioré
sub generate_report {
    my ($tester, $client, $date_test, $bien, $risque, $attaque, $outil, $target, $result, $comment) = @_;
    
    # Nettoyage du nom du client pour le nom de fichier
    my $clean_client = $client;
    $clean_client =~ s/[^\w\-]/_/g;
    
    my $report_file = "$RESULT_DIR/rapport_" . strftime("%Y%m%d_%H%M%S", localtime) . "_" . $clean_client . ".md";
    
    log_message('INFO', "Génération du rapport: $report_file");
    
    open(my $fh, ">:encoding(utf8)", $report_file) or do {
        log_message('ERROR', "Impossible de créer le rapport: $!");
        die "Impossible de créer le rapport : $!";
    };
    
    print $fh "#  Rapport de Test de Sécurité\n\n";
    print $fh "##  Informations Générales\n";
    print $fh "- **Date du test** : $date_test\n";
    print $fh "- **Heure de génération** : " . strftime("%H:%M:%S", localtime) . "\n";
    print $fh "- **Testeur** : $tester\n";
    print $fh "- **Client** : $client\n";
    print $fh "- **Version du script** : $VERSION\n";
    print $fh "\n---\n\n";
    
    print $fh "##  Bien Essentiel Testé\n";
    print $fh "- **Bien essentiel** : $bien\n";
    print $fh "- **Risque associé** : $risque\n";
    print $fh "- **Attaque associée** : $attaque\n";
    print $fh "- **Outil utilisé** : $outil\n";
    print $fh "- **Cible** : $target\n";
    print $fh "\n---\n\n";
    
    print $fh "##  Résultats du Test\n\n";
    print $fh "```\n";
    print $fh "$result\n";
    print $fh "```\n\n";
    
    print $fh "---\n\n";
    print $fh "##  Commentaires\n";
    print $fh "$comment\n\n";
    
    print $fh "---\n\n";
    print $fh "##  Conclusion\n";
    print $fh "Le test a été réalisé avec succès le $date_test. ";
    print $fh "Les résultats détaillés sont disponibles ci-dessus.\n\n";
    
    print $fh "**Métadonnées techniques :**\n";
    print $fh "- Timeout utilisé : ${TIMEOUT}s\n";
    print $fh "- Mode debug : " . ($DEBUG ? "Activé" : "Désactivé") . "\n";
    print $fh "- Mode dry-run : " . ($DRY_RUN ? "Activé" : "Désactivé") . "\n";
    
    close($fh);
    
    log_message('INFO', "Rapport généré avec succès: $report_file");
    print colored(" Rapport généré avec succès : $report_file\n", 'bold green');
    
    return $report_file;
}

# Fonction principale améliorée
sub main {
    print colored(" Script de Test de Sécurité v$VERSION\n", 'bold cyan');
    print colored("=" x 50 . "\n", 'cyan');
    
    eval {
        log_message('INFO', "Démarrage du script v$VERSION");
        
        my ($tester, $client, $date_test) = ask_for_info();
        my $bien = select_bien_essentiel();
        my $risque = associer_risque($bien);
        my $attaque = associer_attaque($risque);
        my $outil = associer_outil($attaque);
        
        check_tool_installed($outil);
        
        my $target = ask_for_target();
        my $result = run_tool($outil, $target);
        my $comment = ask_for_comment();
        
        my $report_file = generate_report($tester, $client, $date_test, $bien, $risque, $attaque, $outil, $target, $result, $comment);
        
        print colored("\n Test terminé avec succès !\n", 'bold green');
        print colored(" Rapport disponible : $report_file\n", 'green');
        
        log_message('INFO', "Script terminé avec succès");
        
    };
    
    if ($@) {
        my $error = $@;
        log_message('ERROR', "Erreur fatale: $error");
        print colored(" Erreur : $error\n", 'bold red');
        exit 1;
    }
}

# Gestion des signaux
$SIG{INT} = $SIG{TERM} = sub {
    log_message('WARN', 'Script interrompu par l\'utilisateur');
    print colored("\n Script interrompu par l'utilisateur\n", 'yellow');
    exit 130;
};

# Point d'entrée
main() unless caller;

__END__

=head1 NAME

script.pl - Script de Test de Sécurité v2.0

=head1 SYNOPSIS

script.pl [OPTIONS]

=head1 OPTIONS

=over 4

=item B<--help, -h>

Affiche cette aide

=item B<--version, -v>

Affiche la version du script

=item B<--debug, -d>

Active le mode debug avec logs détaillés

=item B<--dry-run>

Mode simulation sans exécution réelle des outils

=item B<--timeout SECONDS>

Définit le timeout pour l'exécution des outils (défaut: 300s)

=back

=head1 DESCRIPTION

Ce script automatise les tests de sécurité en utilisant la correspondance
biens essentiels -> risques -> attaques -> outils définie dans les fichiers CSV.

=head1 AUTHOR

Toolbox Security Team

=cut
