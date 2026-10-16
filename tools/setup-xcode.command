#!/bin/bash
# Configuration post-installation de Xcode + telechargement du runtime simulateur iOS.
set -u
DEV="/Applications/Xcode.app/Contents/Developer"

if [ "$(id -u)" -ne 0 ]; then
  echo "======================================================"
  echo " Configuration de Xcode"
  echo " Ton mot de passe administrateur va etre demande."
  echo " (rien ne s'affiche quand tu tapes, c'est normal)"
  echo "======================================================"
  echo
  exec sudo "$0" "$@"
fi

echo "==> [1/4] Activation de la toolchain Xcode..."
xcode-select -s "$DEV" || exit 1
echo "    OK : $(xcode-select -p)"

echo
echo "==> [2/4] Acceptation de la licence Xcode..."
xcodebuild -license accept || exit 1
echo "    OK."

echo
echo "==> [3/4] Installation des composants additionnels..."
xcodebuild -runFirstLaunch || exit 1
echo "    OK."

echo
echo "==> [4/4] Telechargement du runtime simulateur iOS (~10 Go)."
echo "    Cela peut prendre 15 a 60 min selon ta connexion. Ne pas fermer."
xcodebuild -downloadPlatform iOS || {
  echo "    ECHEC. Tu peux reessayer via Xcode > Settings > Components."
  exit 1
}
echo "    OK."

echo
echo "======================================================"
echo " Termine. Runtimes installes :"
xcrun simctl list runtimes
echo "======================================================"
echo
echo "Tu peux fermer cette fenetre et revenir me voir."
