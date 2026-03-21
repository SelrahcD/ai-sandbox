#!/bin/bash
set -e

echo "Adding marketplaces..."
claude plugin marketplace add selrahcd/selrahcd-marketplace
claude plugin marketplace add obra/superpowers-marketplace

echo "Installing plugins..."
claude plugin install dot-claude@selrahcd-marketplace
claude plugin install superpowers@superpowers-marketplace

echo "Done. Run /reload-plugins inside Claude Code to activate."
