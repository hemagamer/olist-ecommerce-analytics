# ==========================================
# PHASE 1: DATABASE CONNECTION & EXTRACTION
# ==========================================
# Load all required libraries at the top
library(DBI)
library(RPostgres)
library(tidyverse)
library(corrplot)

# Establish the Bridge to pgAdmin4
con <- dbConnect(RPostgres::Postgres(),
                 dbname = 'olist',       
                 host = 'localhost',     
                 port = 5432,            
                 user = 'postgres',      
                 password = '123') 

# The Master SQL Query
master_query <- "
  SELECT 
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,
    i.product_id,
    i.price,
    i.freight_value,
    p.product_category_name,
    p.product_weight_g,
    c.customer_state,
    r.review_score
  FROM olist_orders_dataset o
  LEFT JOIN olist_order_items_dataset i ON o.order_id = i.order_id
  LEFT JOIN olist_products_dataset p ON i.product_id = p.product_id
  LEFT JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
  LEFT JOIN olist_order_reviews_dataset r ON o.order_id = r.order_id
  WHERE o.order_status = 'delivered';
"

# Pull the massive dataset into R
df_master <- dbGetQuery(con, master_query)

# Disconnect from the database to save memory
dbDisconnect(con)


# ==========================================
# PHASE 2: DATA ENGINEERING
# ==========================================
# Clean timestamps and engineer the SLA Delay metric
df_clean <- df_master %>%
  mutate(
    estimated_date = as.Date(order_estimated_delivery_date),
    delivered_date = as.Date(order_delivered_customer_date),
    # Calculate the SLA Error (Positive = Late, Negative = Early)
    sla_error_days = as.numeric(difftime(delivered_date, estimated_date, units = "days"))
  ) %>%
  drop_na(sla_error_days, review_score)


# ==========================================
# PHASE 3: ANALYSIS & VISUALIZATION
# ==========================================

# --- 1. THE CORRELATION MATRIX ---
# Use df_clean instead of df_master
df_numeric <- df_clean %>% 
  select(price, freight_value, product_weight_g, sla_error_days, review_score) %>% 
  drop_na()

# Compute the mathematical relationships
cor_matrix <- cor(df_numeric)

# Plot the matrix
corrplot(cor_matrix, 
         method = "color", 
         type = "upper", 
         addCoef.col = "black", 
         tl.col = "black",      
         tl.srt = 45,           
         title = "Macro Ecosystem Correlation Matrix",
         mar = c(0,0,2,0))

# --- 2. GGPLOT2 VISUALIZATION ---
delay_plot <- ggplot(df_clean, aes(x = as.factor(review_score), y = sla_error_days, fill = as.factor(review_score))) +
  geom_boxplot(alpha = 0.8, outlier.shape = 16, outlier.alpha = 0.1) +
  coord_cartesian(ylim = c(-30, 20)) +
  scale_fill_brewer(palette = "RdYlBu") + 
  labs(title = "The Anatomy of a Bad Review",
       subtitle = "How Delivery Delays (SLA Error) Impact Customer Satisfaction",
       x = "Customer Review Score (1 = Worst, 5 = Best)",
       y = "SLA Error in Days (Negative = Early, Positive = Late)") +
  theme_minimal() +
  theme(legend.position = "none",
        plot.title = element_text(face = "bold", size = 16))

print(delay_plot)

# --- 3. MULTIPLE LINEAR REGRESSION ---
sla_model <- lm(review_score ~ sla_error_days + freight_value + price + product_weight_g, data = df_clean)

# Print the statistical output to the Bottom-Left Console
summary(sla_model)