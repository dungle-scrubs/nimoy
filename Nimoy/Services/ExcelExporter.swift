import AppKit
import Foundation

/// Exports Nimoy documents to Excel format (.xlsx)
/// XLSX is a zip archive containing XML files
class ExcelExporter {
    struct ExportRow {
        let text: String
        let assignedValue: String // Could be number, formula, or empty
        let calculatedResult: String
        let rate: String // Exchange rate if applicable
        let isFormula: Bool
    }

    /// Export a Nimoy document to Excel
    /// - Parameters:
    ///   - content: The Nimoy document content
    ///   - results: The evaluation results for each line
    /// - Returns: URL to the temporary xlsx file, or nil on failure
    static func export(content: String, results: [LineResult]) -> URL? {
        let rows = buildRows(content: content, results: results)
        return generateXLSX(rows: rows)
    }

    /// Build export rows from content and results
    private static func buildRows(content: String, results: [LineResult]) -> [ExportRow] {
        let lines = content.components(separatedBy: "\n")
        var rows: [ExportRow] = []
        var variableRows: [String: Int] = [:] // Track which row each variable is on

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
                continue
            }

            let result = index < results.count ? results[index].result : nil
            let rowNum = rows.count + 2 // Excel rows are 1-indexed, +1 for header

            // Parse the line
            let (text, assignedValue, isFormula) = parseLine(
                line: trimmed,
                variableRows: variableRows,
                currentRow: rowNum
            )

            // Track variable assignments for formula references
            if let eqIndex = trimmed.firstIndex(of: "=") {
                let varName = String(trimmed[..<eqIndex]).trimmingCharacters(in: .whitespaces).lowercased()
                if !varName.isEmpty, !varName.contains(" ") {
                    variableRows[varName] = rowNum
                }
            } else {
                // Single word might be a variable reference
                let word = trimmed.lowercased().components(separatedBy: " ").first ?? ""
                if !word.isEmpty {
                    variableRows[word] = rowNum
                }
            }

            // Get calculated result and rate
            let (calcResult, rate) = formatResult(result)

            rows.append(ExportRow(
                text: text,
                assignedValue: assignedValue,
                calculatedResult: calcResult,
                rate: rate,
                isFormula: isFormula
            ))
        }

        return rows
    }

    /// Parse a line into text and assigned value
    private static func parseLine(
        line: String,
        variableRows: [String: Int],
        currentRow: Int
    ) -> (text: String, assignedValue: String, isFormula: Bool) {
        // Check for assignment
        if let eqIndex = line.firstIndex(of: "=") {
            let text = String(line[..<eqIndex]).trimmingCharacters(in: .whitespaces)
            let valueStr = String(line[line.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)

            // Check if it's an aggregate function
            let lowerValue = valueStr.lowercased()

            if lowerValue.hasPrefix("sum") {
                let formula = buildAggregateFormula("SUM", variableRows: variableRows, currentRow: currentRow)
                return (text, formula, true)
            } else if lowerValue.hasPrefix("average") || lowerValue.hasPrefix("avg") {
                let formula = buildAggregateFormula("AVERAGE", variableRows: variableRows, currentRow: currentRow)
                return (text, formula, true)
            } else if lowerValue.hasPrefix("count") {
                let formula = buildAggregateFormula("COUNT", variableRows: variableRows, currentRow: currentRow)
                return (text, formula, true)
            } else if lowerValue.hasPrefix("min") {
                let formula = buildAggregateFormula("MIN", variableRows: variableRows, currentRow: currentRow)
                return (text, formula, true)
            } else if lowerValue.hasPrefix("max") {
                let formula = buildAggregateFormula("MAX", variableRows: variableRows, currentRow: currentRow)
                return (text, formula, true)
            }

            // Check if value references other variables
            let formula = buildCellFormula(valueStr, variableRows: variableRows)
            if formula != valueStr {
                return (text, formula, true)
            }

            // Plain value
            return (text, valueStr, false)
        }

        // No assignment - just text (variable reference)
        let lowerLine = line.lowercased()
        if let row = variableRows[lowerLine.components(separatedBy: " ").first ?? ""] {
            return (line, "=B\(row)", true)
        }

        return (line, "", false)
    }

    /// Build an aggregate formula (SUM, AVERAGE, etc.)
    private static func buildAggregateFormula(
        _ function: String,
        variableRows: [String: Int],
        currentRow: Int
    ) -> String {
        // Find the range of numeric rows above this one
        let rows = variableRows.values.sorted()
        let validRows = rows.filter { $0 < currentRow }

        guard let minRow = validRows.min(), let maxRow = validRows.max() else {
            return "=\(function)(B2:B\(currentRow - 1))"
        }

        return "=\(function)(B\(minRow):B\(maxRow))"
    }

    /// Build a formula that references other cells
    private static func buildCellFormula(_ expression: String, variableRows: [String: Int]) -> String {
        var result = expression

        // Sort by length descending to replace longer variable names first
        let sortedVars = variableRows.keys.sorted { $0.count > $1.count }

        for varName in sortedVars {
            guard let row = variableRows[varName] else { continue }

            // Replace variable name with cell reference (case insensitive)
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: varName))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                result = regex.stringByReplacingMatches(
                    in: result,
                    range: NSRange(result.startIndex..., in: result),
                    withTemplate: "B\(row)"
                )
            }
        }

        // If we made replacements, it's a formula
        if result != expression {
            return "=" + result
        }

        return expression
    }

    /// Format the evaluation result
    private static func formatResult(_ result: EvaluationResult?) -> (value: String, rate: String) {
        guard let result else {
            return ("", "")
        }

        switch result {
        case let .number(value, unit, isCurrencyConversion, _):
            let formatted: String = if let unit {
                unit.format(value)
            } else {
                formatNumber(value)
            }

            // If it's a currency conversion, try to get the rate
            var rate = ""
            if isCurrencyConversion {
                // The rate info would need to come from the conversion
                // For now, we'll leave it as the unit symbol
                if let unit {
                    rate = unit.symbol
                }
            }

            return (formatted, rate)

        case let .text(str):
            return (str, "")

        case let .error(msg):
            return ("Error: \(msg)", "")
        }
    }

    /// Format a number for display
    private static func formatNumber(_ value: Double) -> String {
        if value == floor(value), abs(value) < 1e10 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.2f", value)
    }

    // MARK: - XLSX Generation

    /// Generate an XLSX file from rows
    private static func generateXLSX(rows: [ExportRow]) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let xlsxDir = tempDir.appendingPathComponent(UUID().uuidString)
        let xlsxFile = tempDir.appendingPathComponent("Nimoy-Export-\(dateString()).xlsx")

        do {
            // Create directory structure
            try FileManager.default.createDirectory(at: xlsxDir, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(
                at: xlsxDir.appendingPathComponent("_rels"),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: xlsxDir.appendingPathComponent("xl"),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: xlsxDir.appendingPathComponent("xl/_rels"),
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: xlsxDir.appendingPathComponent("xl/worksheets"),
                withIntermediateDirectories: true
            )

            // Write XML files
            try contentTypesXML().write(
                to: xlsxDir.appendingPathComponent("[Content_Types].xml"),
                atomically: true,
                encoding: .utf8
            )
            try relsXML().write(to: xlsxDir.appendingPathComponent("_rels/.rels"), atomically: true, encoding: .utf8)
            try workbookXML().write(
                to: xlsxDir.appendingPathComponent("xl/workbook.xml"),
                atomically: true,
                encoding: .utf8
            )
            try workbookRelsXML().write(
                to: xlsxDir.appendingPathComponent("xl/_rels/workbook.xml.rels"),
                atomically: true,
                encoding: .utf8
            )
            try stylesXML().write(
                to: xlsxDir.appendingPathComponent("xl/styles.xml"),
                atomically: true,
                encoding: .utf8
            )
            try sheetXML(rows: rows).write(
                to: xlsxDir.appendingPathComponent("xl/worksheets/sheet1.xml"),
                atomically: true,
                encoding: .utf8
            )

            // Zip the directory
            try zipDirectory(xlsxDir, to: xlsxFile)

            // Clean up temp directory
            try? FileManager.default.removeItem(at: xlsxDir)

            return xlsxFile

        } catch {
            print("Excel export error: \(error)")
            try? FileManager.default.removeItem(at: xlsxDir)
            return nil
        }
    }

    private static func dateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }

    // MARK: - XML Templates

    private static func contentTypesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
            <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
            <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
        </Types>
        """
    }

    private static func relsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
        </Relationships>
        """
    }

    private static func workbookXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
            <sheets>
                <sheet name="Nimoy Export" sheetId="1" r:id="rId1"/>
            </sheets>
        </workbook>
        """
    }

    private static func workbookRelsXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
            <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
        </Relationships>
        """
    }

    private static func stylesXML() -> String {
        """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <fonts count="2">
                <font><sz val="11"/><name val="Calibri"/></font>
                <font><b/><sz val="11"/><name val="Calibri"/></font>
            </fonts>
            <fills count="2">
                <fill><patternFill patternType="none"/></fill>
                <fill><patternFill patternType="gray125"/></fill>
            </fills>
            <borders count="1">
                <border><left/><right/><top/><bottom/><diagonal/></border>
            </borders>
            <cellStyleXfs count="1">
                <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
            </cellStyleXfs>
            <cellXfs count="2">
                <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
                <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>
            </cellXfs>
        </styleSheet>
        """
    }

    private static func sheetXML(rows: [ExportRow]) -> String {
        var cellsXML = ""

        // Header row (bold - style 1)
        cellsXML += """
            <row r="1">
                <c r="A1" t="inlineStr" s="1"><is><t>Description</t></is></c>
                <c r="B1" t="inlineStr" s="1"><is><t>Value/Formula</t></is></c>
                <c r="C1" t="inlineStr" s="1"><is><t>Result</t></is></c>
                <c r="D1" t="inlineStr" s="1"><is><t>Rate/Unit</t></is></c>
            </row>
        """

        // Data rows
        for (index, row) in rows.enumerated() {
            let rowNum = index + 2
            cellsXML += "<row r=\"\(rowNum)\">"

            // Column A - Text
            cellsXML += "<c r=\"A\(rowNum)\" t=\"inlineStr\"><is><t>\(escapeXML(row.text))</t></is></c>"

            // Column B - Assigned Value (formula or value)
            if row.isFormula {
                cellsXML += "<c r=\"B\(rowNum)\"><f>\(escapeXML(String(row.assignedValue.dropFirst())))</f></c>"
            } else if let numValue = Double(row.assignedValue.replacingOccurrences(of: ",", with: "")) {
                cellsXML += "<c r=\"B\(rowNum)\"><v>\(numValue)</v></c>"
            } else if !row.assignedValue.isEmpty {
                cellsXML += "<c r=\"B\(rowNum)\" t=\"inlineStr\"><is><t>\(escapeXML(row.assignedValue))</t></is></c>"
            } else {
                cellsXML += "<c r=\"B\(rowNum)\"/>"
            }

            // Column C - Calculated Result
            let resultValue = row.calculatedResult
                .replacingOccurrences(of: ",", with: "")
                .components(separatedBy: " ").first ?? ""
            if let numValue = Double(resultValue) {
                cellsXML += "<c r=\"C\(rowNum)\"><v>\(numValue)</v></c>"
            } else if !row.calculatedResult.isEmpty {
                cellsXML += "<c r=\"C\(rowNum)\" t=\"inlineStr\"><is><t>\(escapeXML(row.calculatedResult))</t></is></c>"
            } else {
                cellsXML += "<c r=\"C\(rowNum)\"/>"
            }

            // Column D - Rate/Unit
            if !row.rate.isEmpty {
                cellsXML += "<c r=\"D\(rowNum)\" t=\"inlineStr\"><is><t>\(escapeXML(row.rate))</t></is></c>"
            } else {
                cellsXML += "<c r=\"D\(rowNum)\"/>"
            }

            cellsXML += "</row>"
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <cols>
                <col min="1" max="1" width="30" customWidth="1"/>
                <col min="2" max="2" width="20" customWidth="1"/>
                <col min="3" max="3" width="20" customWidth="1"/>
                <col min="4" max="4" width="15" customWidth="1"/>
            </cols>
            <sheetData>
                \(cellsXML)
            </sheetData>
        </worksheet>
        """
    }

    private static func escapeXML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    // MARK: - Zip

    private static func zipDirectory(_ sourceDir: URL, to destFile: URL) throws {
        // Use NSFileCoordinator and Archive utility
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", destFile.path, "."]
        process.currentDirectoryURL = sourceDir

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "ExcelExporter",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Failed to create zip archive"]
            )
        }
    }
}
