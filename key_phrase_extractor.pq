// Use this function to remove or replace keywords and phrases in text before running Cognitive Services Key Phrase Extraction
// Credit to Chris Webb for inspiration and guidance via this blog post: blog.crossjoin.co.uk/2014/06/25/using-list-generate-to-make-multiple-replacements-of-words-in-text-in-power-query
 
// Inputs are based on one query containing text to analyze (data table) and an additional query (replacements) of keywords and phrases to replace
// Replacements query should contain two columns. The first column is a distinct list of text to replace. The second column is the corresponding replacement value.
// Only non-null values should be included in replacements query. Blanks or nulls should be represented with text whitespace.
// As the function loops through the replacements query values are not safe so order the replacements accordingly.
// eg 1. High-Five to Hand-Smack 2. mac to windows --> erroneous correction to Hand-Swindowsk. Instead 1. mac to windows 2. High-Five to Hand-Smack --> still Hand-Smack

// Output is a new query with columns indicating the original text, cleaned text, and extracted phrases

( TextToChange as list, WordsToReplace as list, WordsToReplaceWith as list ) =>
let
    TextTable = Table.TransformColumnTypes(Table.FromList(TextToChange),{{"Column1", type text}}),
    
    ExtractKeyPhrases = AIFunctions.Contents(){[Key = "CognitiveServices.ExtractKeyPhrasestexttext"]}[Data],
   
    ReplacementFunction = (InputText)=> 
     let
       DoReplacement = List.Generate(
                          ()=> [Counter=0, MyText=InputText], 
                          each [Counter]<=List.Count(WordsToReplaceWith), 
                          each [Counter=[Counter]+1, 
                                MyText=Text.Replace(
                                         [MyText], 
                                         WordsToReplace{[Counter]}, 
                                         WordsToReplaceWith{[Counter]})], 
                          each [MyText]),

       GetLastValue = List.Last(DoReplacement)
     in
      GetLastValue,

    Output = Table.AddColumn(TextTable, "Changed Text", each ReplacementFunction([Column1]), type text),
    #"Applied Extract key phrases" = AIFunctions.PostProcess(Table.AddColumn(Output, "Extract key phrases", each ExtractKeyPhrases([Changed Text], null)), "Extract key phrases", "CognitiveServices.ExtractKeyPhrasestexttext") meta [FunctionBrowser="TextAnalytics"]
in
    #"Applied Extract key phrases"
