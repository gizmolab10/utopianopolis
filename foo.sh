echo "\`\`\`
$(sw_vers)

$(xcode-select -p)
$(xcodebuild -version)

$(which pod && pod --version)
$(test -e Podfile.lock && cat Podfile.lock | sed -nE 's/^  - (Realm(Swift)? [^:]*):?/\1/p' || echo "(not in use here)")

$(which bash && bash -version | head -n1)

$(which carthage && carthage version)
$(test -e Cartfile.resolved && cat Cartfile.resolved | grep --color=no realm || echo "(not in use here)")

$(which git && git --version)
\`\`\`" | tee /dev/tty | pbcopy
