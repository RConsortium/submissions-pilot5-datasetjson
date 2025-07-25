# A provider-based LLM API using ellmer

library(ellmer)
library(here)
library(jsonlite)
#source(here("pipeline", "utils", "logging.R"))

# Define default environment variables for various providers
PROVIDER_ENV_VARS <- list(
  "openai" = "OPENAI_API_KEY",
  "anthropic" = "ANTHROPIC_API_KEY",
  "deepseek" = "DEEPSEEK_API_KEY",
  "gemini" = "GOOGLE_API_KEY",
  "groq" = "GROQ_API_KEY",
  "perplexity" = "PERPLEXITY_API_KEY",
  "openrouter" = "OPENROUTER_API_KEY",
  "github" = "GITHUB_API_KEY",
  "vllm" = "VLLM_API_KEY",
  "azure" = "AZURE_API_KEY",
  "bedrock" = "AWS_ACCESS_KEY_ID",
  "databricks" = "DATABRICKS_TOKEN",
  "snowflake" = "SNOWFLAKE_TOKEN"
)

# Map of provider names to their ellmer function names
PROVIDER_FUNCTIONS <- list(
  "openai" = "chat_openai",
  "anthropic" = "chat_claude",
  "deepseek" = "chat_deepseek",
  "azure" = "chat_azure",
  "bedrock" = "chat_bedrock",
  "databricks" = "chat_databricks",
  "gemini" = "chat_gemini",
  "github" = "chat_github",
  "groq" = "chat_groq",
  "ollama" = "chat_ollama",
  "openrouter" = "chat_openrouter",
  "perplexity" = "chat_perplexity",
  "snowflake" = "chat_snowflake",
  "vllm" = "chat_vllm"
)

# Define a mapping of model name patterns to providers
# This supports backward compatibility for inferring provider from model name
MODEL_TO_PROVIDER_MAP <- list(
  # OpenAI models
  "^gpt-" = "openai",
  "^o[0-9]" = "openai",
  "^text-" = "openai",

  # Anthropic Claude models
  "^claude" = "anthropic",

  # DeepSeek models
  "^deepseek" = "deepseek",

  # Gemini models
  "^gemini" = "gemini",

  # Mistral models via Groq
  "^mistral" = "groq",
  "^mixtral" = "groq",

  # Llama models (typically via Ollama)
  "^llama" = "ollama",

  # Azure models - harder to infer, often uses deployment ID
  "^azure-" = "azure"
)

# Provider documentation URL
PROVIDERS_DOC_URL <- "https://ellmer.tidyverse.org/reference/index.html"

#' Infer provider from model name
#'
#' @param model The model name
#' @return The inferred provider or NULL if unable to infer
#' @keywords internal
infer_provider_from_model <- function(model) {
  if (is.null(model)) {
    return(NULL)
  }

  # Check against our model patterns
  for (pattern in names(MODEL_TO_PROVIDER_MAP)) {
    if (grepl(pattern, model, ignore.case = TRUE)) {
      return(MODEL_TO_PROVIDER_MAP[[pattern]])
    }
  }

  # If we can't infer, return NULL
  return(NULL)
}

#' Create a chat object for any provider
#'
#' @param provider The provider name (if NULL, will attempt to infer from model)
#' @param model The model name (or NULL to use provider's default)
#' @param system_prompt Optional system prompt
#' @param api_key Optional API key
#' @param base_url Optional base URL
#' @param ... Additional arguments for the provider's chat function
#' @return An ellmer chat object
#' @export
create_chat_object <- function(provider = NULL, model = NULL, system_prompt = NULL,
                               api_key = NULL, base_url = NULL, ...) {
  # Try to infer provider from model if not explicitly provided
  if (is.null(provider) && !is.null(model)) {
    inferred_provider <- infer_provider_from_model(model)

    if (!is.null(inferred_provider)) {
      provider <- inferred_provider
    } else {
      stop(paste(
        "Could not infer provider from model name:", model,
        "\nPlease specify the provider explicitly, e.g., provider='openai', provider='anthropic', etc.",
        "\nSee", PROVIDERS_DOC_URL, "for supported providers and models."
      ))
    }
  } else if (is.null(provider)) {
    stop("Provider must be specified when model is NULL")
  }

  # Standardize provider name to lowercase
  provider <- tolower(provider)

  # Check if provider is supported
  if (!provider %in% names(PROVIDER_FUNCTIONS)) {
    stop(sprintf(
      "Provider '%s' not supported. Supported providers: %s\nSee %s for details.",
      provider,
      paste(names(PROVIDER_FUNCTIONS), collapse = ", "),
      PROVIDERS_DOC_URL
    ))
  }

  # Get API key from environment if not provided
  if (is.null(api_key) && provider %in% names(PROVIDER_ENV_VARS)) {
    env_var <- PROVIDER_ENV_VARS[[provider]]
    api_key <- Sys.getenv(env_var)

    # For AWS Bedrock, additional environment variables may be needed
    if (provider == "bedrock" && nchar(api_key) > 0) {
      aws_secret <- Sys.getenv("AWS_SECRET_ACCESS_KEY")
      if (nchar(aws_secret) == 0) {
        warning("AWS_SECRET_ACCESS_KEY environment variable is not set. Bedrock authentication may fail.")
      }
    }
  }

  # Create arguments list for the chat function
  chat_args <- list(
    system_prompt = system_prompt,
    echo = "none"
  )

  # Add model if specified
  if (!is.null(model)) {
    chat_args$model <- model
  }

  # Add API key if available
  if (!is.null(api_key) && nchar(api_key) > 0) {
    # Different providers use different parameter names for API keys
    if (provider %in% c("databricks", "snowflake")) {
      chat_args$token <- api_key
    } else {
      chat_args$api_key <- api_key
    }
  }

  # Add base_url if provided
  if (!is.null(base_url)) {
    chat_args$base_url <- base_url
  }

  # Add any additional arguments
  chat_args <- c(chat_args, list(...))

  # Get the appropriate chat function for this provider
  chat_fn_name <- PROVIDER_FUNCTIONS[[provider]]

  # Try to get the function and handle errors
  tryCatch(
    {
      chat_fn <- get(chat_fn_name, envir = asNamespace("ellmer"))

      # Create chat object
      chat <- do.call(chat_fn, chat_args)

      return(chat)
    },
    error = function(e) {
      # Just pass through the error with the documentation URL
      stop(sprintf(
        "%s\nSee %s for more information.",
        e$message,
        PROVIDERS_DOC_URL
      ))
    }
  )
}

# Helper function for retrying with exponential backoff
retry_with_exponential_backoff <- function(expr, max_attempts = 5, initial_delay = 2, multiplier = 2) {
  attempt <- 1
  delay <- initial_delay
  while (attempt <= max_attempts) {
    result <- tryCatch(expr(), error = function(e) e)
    if (!inherits(result, "error")) {
      return(result)
    }
    message(sprintf("Attempt %d failed: %s. Retrying in %d seconds...", 
                    attempt, result$message, delay))
    Sys.sleep(delay)
    delay <- delay * multiplier
    attempt <- attempt + 1
  }
  stop(sprintf("Failed after %d attempts. Last error: %s", 
               max_attempts, result$message))
}


#' Primary function for LLM API calls
#'
#' @param prompt The prompt to send to the LLM
#' @param provider The provider name (will attempt to infer from model if NULL)
#' @param model The model to use (required)
#' @param system_prompt Optional system prompt
#' @param api_key Optional API key (if NULL, will look for environment variable)
#' @param base_url Optional base URL (for self-hosted models)
#' @param ... Additional arguments passed to the provider-specific chat function
#' @return The text response from the LLM
#' @export
llm_call <- function(prompt, provider = NULL, model, system_prompt = NULL,
                     api_key = NULL, base_url = NULL, ...) {
  if (missing(model) || is.null(model)) {
    stop("Model must be specified. `model` is now a required argument.")
  }
  
  # Create chat object (handles provider inference if needed)
  chat <- create_chat_object(
    provider = provider,
    model = model,
    system_prompt = system_prompt,
    api_key = api_key,
    base_url = base_url,
    ...
  )
  
  # Send prompt with retry
  response <- retry_with_exponential_backoff(function() chat$chat(prompt))
  
  # Log the call
  effective_provider <- if (!is.null(provider)) provider else infer_provider_from_model(model)
  model_tag <- paste0(effective_provider, "-", model)
  log_llm_call(prompt, model_tag, response)
  
  return(response)
}


#' Extract structured data using an LLM
#'
#' @param prompt The text prompt to extract data from
#' @param provider The provider name (if NULL, will attempt to infer from model)
#' @param type An ellmer type specification
#' @param model The model to use (or NULL to use provider's default)
#' @param system_prompt Optional system prompt to guide extraction
#' @param api_key Optional API key (if NULL, will look for environment variable)
#' @param base_url Optional base URL (for self-hosted models)
#' @param ... Additional arguments passed to the provider-specific chat function
#' @return Structured data as an R object
#' @export
llm_extract_structured <- function(prompt, provider = NULL, type, model = NULL,
                                   system_prompt = NULL, api_key = NULL,
                                   base_url = NULL, ...) {
  # Create chat object (will handle provider inference if needed)
  chat <- create_chat_object(
    provider = provider,
    model = model,
    system_prompt = system_prompt,
    api_key = api_key,
    base_url = base_url,
    ...
  )
  
  # Extract structured data using retry logic
  result <- retry_with_exponential_backoff(function() chat$extract_data(prompt, type = type))
  
  # Log the extraction
  inferred_provider <- ifelse(is.null(provider) && !is.null(model),
                              infer_provider_from_model(model),
                              provider
  )
  model_tag <- ifelse(is.null(model),
                      paste0(inferred_provider, "-default"),
                      paste0(inferred_provider, "-", model)
  )
  
  log_extraction <- paste0(
    "STRUCTURED DATA EXTRACTION\n",
    "Provider: ", inferred_provider, "\n",
    "Model: ", ifelse(is.null(model), "default", model), "\n",
    "Prompt: ", prompt, "\n",
    "Result: ", jsonlite::toJSON(result, auto_unbox = TRUE, pretty = TRUE)
  )
  log_llm_call(prompt, model_tag, log_extraction)
  
  return(result)
}

# Maintain support for traditional usage where `llm_call(prompt, model)` was the format
llm_call_legacy <- function(prompt, model, ...) {
  # This function maintains backward compatibility with code that used the older format
  llm_call(prompt = prompt, model = model, ...)
}

# Overwrite llm_call with a function that will determine the correct calling convention
llm_call_new <- llm_call # Save new implementation
llm_call <- function(prompt, provider = NULL, model = NULL, ...) {
  # If second arg is not NULL and third arg is NULL, assume old calling convention
  # (prompt, model) where model is the second argument
  if (missing(provider) || missing(model)) {
    # In case they weren't provided at all
    if (missing(provider)) provider <- NULL
    if (missing(model)) model <- NULL
  }

  if (!is.null(provider) && is.null(model) && !grepl("^[a-zA-Z]+$", provider)) {
    # If provider doesn't look like a provider name (i.e., it contains non-alphabetic chars),
    # assume it's actually the model name in the old calling convention
    return(llm_call_legacy(prompt, model = provider, ...))
  } else {
    # Use the new implementation
    return(llm_call_new(prompt, provider, model, ...))
  }
}
