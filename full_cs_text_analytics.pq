// Function can bulk replace or omit words and phrases. Additionally it can leverage any number of available Cognitive Services Text Analytics options.

= ( #"Text to Analyze" as list, 
  #"Words/Phrases to Replace" as nullable list, 
  #"Words/Phrases to Replace With" as nullable list, 
  #"Detect Language (true/false)" as logical,
  #"Extract Key Phrases (true/false)" as logical, 
  #"Score Sentiment (true/false)" as logical ) =>

let
    TextList = List.Buffer(#"Text to Analyze"),
    ReplaceWords = if #"Words/Phrases to Replace" = null then null else List.Buffer(#"Words/Phrases to Replace"),
    ReplaceWith = if #"Words/Phrases to Replace With" = null then null else List.Buffer(#"Words/Phrases to Replace With"),
    TextTable = Table.TransformColumnTypes(Table.FromList(TextList),{{"Column1", type text}}),

    DetectLanguage = if #"Detect Language (true/false)" = false then null else AIFunctions.Contents(){[Key = "CognitiveServices.DetectLanguagetext"]}[Data],
    ExtractKeyPhrases = if #"Extract Key Phrases (true/false)" = false then null else AIFunctions.Contents(){[Key = "CognitiveServices.ExtractKeyPhrasestexttext"]}[Data],
   
    ReplacementFunction = if ReplaceWords = null then null else (InputText)=> 
     let
       DoReplacement = List.Generate(
                          ()=> [Counter=0, MyText=InputText], 
                          each [Counter]<=List.Count(ReplaceWith), 
                          each [Counter=[Counter]+1, 
                                MyText=Text.Replace(
                                         [MyText], 
                                         ReplaceWords{[Counter]}, 
                                         ReplaceWith{[Counter]})], 
                          each [MyText]),

       GetLastValue = List.Last(DoReplacement)
     in
      GetLastValue,


    DetectLanguageFunction = if #"Detect Language (true/false)" = false then null else (InputTable1 as nullable table)=>
      let 
        DetectLanguage = AIFunctions.Contents(){[Key = "CognitiveServices.DetectLanguagetext"]}[Data],
        AppliedDetectLanguage = AIFunctions.PostProcess(Table.AddColumn(InputTable1, "Detect language", each DetectLanguage([Changed Text]), type text), "Detect language", "CognitiveServices.DetectLanguagetext") meta [FunctionBrowser="TextAnalytics"]
      in
        AppliedDetectLanguage,


    ExtractKeyPhrasesFunction = if #"Extract Key Phrases (true/false)" = false then null else (InputTable2 as nullable table)=>
      let  
        ExtractKeyPhrases = AIFunctions.Contents(){[Key = "CognitiveServices.ExtractKeyPhrasestexttext"]}[Data],
        AppliedExtractKeyPhrases = AIFunctions.PostProcess(Table.AddColumn(InputTable2, "Extract key phrases", each ExtractKeyPhrases([Changed Text], null), type text), "Extract key phrases", "CognitiveServices.ExtractKeyPhrasestexttext") meta [FunctionBrowser="TextAnalytics"]
      in  
        AppliedExtractKeyPhrases,
        

    ScoreSentimentFunction = if #"Score Sentiment (true/false)" = false then null else (InputTable3 as nullable table)=>
      let
        ScoreSentiment = AIFunctions.Contents(){[Key = "CognitiveServices.ScoreSentimenttexttext"]}[Data],
        AppliedScoreSentiment = AIFunctions.PostProcess(Table.AddColumn(InputTable3, "Score sentiment", each ScoreSentiment([Changed Text], null),type number), "Score sentiment", "CognitiveServices.ScoreSentimenttexttext") meta [FunctionBrowser="TextAnalytics"]
      in  
        AppliedScoreSentiment,

    
    Output = if ReplaceWords = null then Table.RenameColumns(TextTable,{{"Column1", "Changed Text"}}) else Table.AddColumn(TextTable, "Changed Text", each ReplacementFunction([Column1]), type text),

    CallLanguageDetection = if #"Detect Language (true/false)" = false then Output else DetectLanguageFunction(Output),
    CallExtractPhrases = if #"Extract Key Phrases (true/false)" = false then CallLanguageDetection else ExtractKeyPhrasesFunction(CallLanguageDetection),
    CallScoreSentiment = if #"Score Sentiment (true/false)" = false then CallExtractPhrases else ScoreSentimentFunction(CallExtractPhrases)    

in
    CallScoreSentiment
