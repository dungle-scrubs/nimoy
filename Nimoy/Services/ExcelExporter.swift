import AppKit
import Foundation

/// Exports Nimoy documents to Excel format (.xlsx)
/// XLSX is a zip archive containing XML files
class ExcelExporter {
    struct ExportRow {
        let description: String
        let value: Double? // Numeric value (for formulas)
        let valueFormula: String? // Excel formula if applicable
        let unit: String // Unit type (THB, USD, etc.)
        let resultValue: Double? // Calculated result
        let resultUnit: String // Result unit
    }

    /// Export a Nimoy document to Excel
    static func export(content: String, results: [LineResult]) -> URL? {
        let rows = buildRows(content: content, results: results)
        return generateXLSX(rows: rows)
    }

    /// Build export rows from content and results
    private static func buildRows(content: String, results: [LineResult]) -> [ExportRow] {
        let lines = content.components(separatedBy: "\n")
        var rows: [ExportRow] = []
        var variableRows: [String: Int] = [:] // Track which row each variable is on (1-indexed for Excel)

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
                continue
            }

            let result = index < results.count ? results[index].result : nil
            let rowNum = rows.count + 2 // Excel rows are 1-indexed, +1 for header

            // Parse the line
            let row = parseLine(
                line: trimmed,
                result: result,
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
                let words = trimmed.lowercased().components(separatedBy: .whitespaces)
                if let firstWord = words.first, !firstWord.isEmpty {
                    variableRows[firstWord] = rowNum
                }
            }

            if let row {
                rows.append(row)
            }
        }

        return rows
    }

    /// Parse a line into an export row
    private static func parseLine(
        line: String,
        result: EvaluationResult?,
        variableRows: [String: Int],
        currentRow: Int
    ) -> ExportRow? {
        var description = ""
        var value: Double?
        var valueFormula: String?
        var unit = ""
        var resultValue: Double?
        var resultUnit = ""

        // Extract result info
        if let result {
            switch result {
            case let .number(val, unitObj, _, _):
                resultValue = val
                resultUnit = unitObj?.symbol ?? ""
            case .text, .error:
                break
            }
        }

        // Check for assignment
        if let eqIndex = line.firstIndex(of: "=") {
            description = String(line[..<eqIndex]).trimmingCharacters(in: .whitespaces)
            let valueStr = String(line[line.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)

            // Check if it's an aggregate function
            let lowerValue = valueStr.lowercased()

            if lowerValue.hasPrefix("sum") {
                valueFormula = buildAggregateFormula("SUM", variableRows: variableRows, currentRow: currentRow)
                // Extract unit from "sum in THB" or just "sum"
                if lowerValue.contains(" in ") {
                    let parts = valueStr.components(separatedBy: " in ")
                    if parts.count > 1 {
                        unit = parts[1].trimmingCharacters(in: .whitespaces)
                    }
                }
            } else if lowerValue.hasPrefix("average") || lowerValue.hasPrefix("avg") {
                valueFormula = buildAggregateFormula("AVERAGE", variableRows: variableRows, currentRow: currentRow)
            } else if lowerValue.hasPrefix("count") {
                valueFormula = buildAggregateFormula("COUNT", variableRows: variableRows, currentRow: currentRow)
            } else if lowerValue.hasPrefix("min") {
                valueFormula = buildAggregateFormula("MIN", variableRows: variableRows, currentRow: currentRow)
            } else if lowerValue.hasPrefix("max") {
                valueFormula = buildAggregateFormula("MAX", variableRows: variableRows, currentRow: currentRow)
            } else {
                // Parse value and unit from assignment like "500 THB"
                let parsed = parseValueAndUnit(valueStr)
                value = parsed.value
                unit = parsed.unit

                // Check if value references other variables
                if value == nil {
                    let formula = buildCellFormula(valueStr, variableRows: variableRows)
                    if formula != valueStr {
                        valueFormula = formula
                    }
                }
            }
        } else {
            // No assignment - might be a variable reference like "rent" or "cosmetics"
            description = line

            // Check if it matches a known variable
            let lowerLine = line.lowercased().components(separatedBy: .whitespaces).first ?? ""
            if let refRow = variableRows[lowerLine] {
                valueFormula = "=B\(refRow)"
            }
        }

        return ExportRow(
            description: description,
            value: value,
            valueFormula: valueFormula,
            unit: unit,
            resultValue: resultValue,
            resultUnit: resultUnit
        )
    }

    /// Parse a value string like "500 THB" into value and unit
    private static func parseValueAndUnit(_ str: String) -> (value: Double?, unit: String) {
        let parts = str.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        if parts.isEmpty {
            return (nil, "")
        }

        // Try to parse first part as number
        let numStr = parts[0].replacingOccurrences(of: ",", with: "")
        if let num = Double(numStr) {
            let unit = parts.count > 1 ? parts[1...].joined(separator: " ") : ""
            return (num, unit)
        }

        // Not a number, might be a variable reference or expression
        return (nil, "")
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

    // MARK: - XLSX Generation

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
                <c r="B1" t="inlineStr" s="1"><is><t>Value</t></is></c>
                <c r="C1" t="inlineStr" s="1"><is><t>Unit</t></is></c>
                <c r="D1" t="inlineStr" s="1"><is><t>Result</t></is></c>
                <c r="E1" t="inlineStr" s="1"><is><t>Result Unit</t></is></c>
            </row>
        """

        // Data rows
        for (index, row) in rows.enumerated() {
            let rowNum = index + 2
            cellsXML += "<row r=\"\(rowNum)\">"

            // Column A - Description (text)
            cellsXML += "<c r=\"A\(rowNum)\" t=\"inlineStr\"><is><t>\(escapeXML(row.description))</t></is></c>"

            // Column B - Value (number or formula)
            if let formula = row.valueFormula {
                // Remove the leading = for the formula element
                let formulaContent = formula.hasPrefix("=") ? String(formula.dropFirst()) : formula
                cellsXML += "<c r=\"B\(rowNum)\"><f>\(escapeXML(formulaContent))</f></c>"
            } else if let value = row.value {
                cellsXML += "<c r=\"B\(rowNum)\"><v>\(value)</v></c>"
            } else {
                cellsXML += "<c r=\"B\(rowNum)\"/>"
            }

            // Column C - Unit (text)
            if !row.unit.isEmpty {
                cellsXML += "<c r=\"C\(rowNum)\" t=\"inlineStr\"><is><t>\(escapeXML(row.unit))</t></is></c>"
            } else {
                cellsXML += "<c r=\"C\(rowNum)\"/>"
            }

            // Column D - Result (number)
            if let resultValue = row.resultValue {
                cellsXML += "<c r=\"D\(rowNum)\"><v>\(resultValue)</v></c>"
            } else {
                cellsXML += "<c r=\"D\(rowNum)\"/>"
            }

            // Column E - Result Unit (text)
            if !row.resultUnit.isEmpty {
                cellsXML += "<c r=\"E\(rowNum)\" t=\"inlineStr\"><is><t>\(escapeXML(row.resultUnit))</t></is></c>"
            } else {
                cellsXML += "<c r=\"E\(rowNum)\"/>"
            }

            cellsXML += "</row>"
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <cols>
                <col min="1" max="1" width="25" customWidth="1"/>
                <col min="2" max="2" width="15" customWidth="1"/>
                <col min="3" max="3" width="10" customWidth="1"/>
                <col min="4" max="4" width="15" customWidth="1"/>
                <col min="5" max="5" width="12" customWidth="1"/>
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
