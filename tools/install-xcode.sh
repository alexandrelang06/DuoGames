#!/bin/bash
# Installe Xcode 26.6 depuis le .xip telecharge. Tout reste sur le SSD interne.
set -u

echo "==> Recherche du .xip Xcode dans ~/Downloads ..."
XIP=$(ls -t ~/Downloads/Xcode*.xip 2>/dev/null | head -1)
if [ -z "${XIP:-}" ]; then
  echo "ERREUR : aucun Xcode*.xip trouve dans ~/Downloads"
  exit 1
fi
echo "    Trouve : $XIP"
echo "    Taille : $(du -h "$XIP" | cut -f1)"

echo "==> Verification de l'espace disque..."
FREE_GB=$(df -g / | awk 'NR==2 {print $4}')
echo "    Libre sur / : ${FREE_GB} GB (il en faut ~60 pour decompresser sereinement)"
if [ "$FREE_GB" -lt 60 ]; then
  echo "ERREUR : espace insuffisant."
  exit 1
fi

echo "==> Verification de la signature Apple..."
if ! pkgutil --check-signature "$XIP" | grep -q "Apple"; then
  echo "ERREUR : signature invalide. Ne pas installer, retelecharger."
  exit 1
fi
echo "    Signature Apple valide."

if [ -d "/Applications/Xcode.app" ]; then
  echo "ATTENTION : /Applications/Xcode.app existe deja -> renomme en Xcode-old.app"
  mv "/Applications/Xcode.app" "/Applications/Xcode-old.app" || exit 1
fi

echo "==> Decompression (10 a 25 min sur ce Mac Intel, ne pas interrompre)..."
cd /Applications || exit 1
if ! xip --expand "$XIP"; then
  echo "ERREUR pendant la decompression."
  exit 1
fi
echo "    Xcode.app installe dans /Applications."
echo
echo "==> Le .xip ($(du -h "$XIP" | cut -f1)) n'est plus necessaire."
echo "    Pour le supprimer :  rm \"$XIP\""
echo
echo "==> Derniere etape, dans Terminal.app (mot de passe admin requis) :"
echo
echo '    sudo xcode-select -s /Applications/Xcode.app/Contents/Developer'
echo '    sudo xcodebuild -license accept'
echo '    sudo xcodebuild -runFirstLaunch'
echo
