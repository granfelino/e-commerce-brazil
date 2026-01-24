# Brazillian e-commerce dataset analysis

* Data source: [LINK](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce?select=product_category_name_translation.csv)

![Data schema](https://i.imgur.com/HRhd2Y0.png)
Data schema of the dataset (image taken from the source site).

* This dataset is big. To clean it and validate it I need a bit of time. For now I will focus on what I think is the core of the dataset:
    1. `orders`
    2. `order\_items`
    3. `customers`
    4. `products`

* I will also add a table with translations of the categories provided by the data poster.
* Apart from that there is information about reviews, payments, sellers and geolocation of the actors. This will come after the core analysis.
* According to the poster of this dataset the data is real and therefore some columns were anonymized (e.g. by replacing companies' names with Game of Thrones house names).

-----
* I will proceed as follows:
    1. Load the datasets into SQL.
    2. Clean the datasets into SQL & prepare theirs ready-to-analyze versions.
    3. Join & aggregate.
    4. Load the aggregated data into Excel and Python for furhter analysis and vizualisation.

* I focused on cleaning customers well
