#!/bin/bash
# Script to find functions missing documentation
# Usage: ./scripts/add-docs.sh [file.swift]

echo "🔍 Finding functions without documentation..."
echo ""

find_undocumented() {
    local file="$1"
    awk '
        BEGIN { in_comment = 0 }
        /\/\*/ { in_comment = 1 }
        /\*\// { in_comment = 0; next }
        in_comment { next }
        
        /^[[:space:]]*(public[[:space:]]+|private[[:space:]]+|internal[[:space:]]+|fileprivate[[:space:]]+|@[A-Za-z]+[[:space:]]+)*(func|init)[[:space:]]/ {
            if (prev !~ /\/\/\/|\/\*\*|\*\//) {
                # Extract function signature
                gsub(/^[[:space:]]+/, "")
                print FILENAME ":" NR
                print "  " $0
                print ""
            }
        }
        { prev = $0 }
    ' "$file"
}

if [ -n "$1" ]; then
    # Single file
    find_undocumented "$1"
else
    # All Swift files
    find Nimoy -name "*.swift" | while read file; do
        find_undocumented "$file"
    done
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📝 Swift Documentation Format (DocC):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
cat << 'EOF'

/// Brief description of what the function does.
///
/// Longer description if needed. Can span multiple lines
/// and include more details about the implementation.
///
/// - Parameters:
///   - paramName: Description of this parameter
///   - anotherParam: Description of another parameter
/// - Returns: Description of the return value
/// - Throws: Description of errors that can be thrown
///
/// ## Example
/// ```swift
/// let result = myFunction(param: "value")
/// ```
///
/// - Note: Any important notes
/// - Warning: Any warnings
/// - SeeAlso: ``RelatedFunction``
func myFunction(paramName: String, anotherParam: Int) throws -> Bool {
    // ...
}

EOF
