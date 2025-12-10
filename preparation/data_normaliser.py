# %%
from functools import wraps
from copy import deepcopy
from pandas.core.base import PandasObject
import pandas as pd
import json
from IPython.display import display
from sqlalchemy import create_engine, text


def as_method(func):
    """
    This decrator makes a function also available as a method.
    The first passed argument must be a DataFrame.
    """
    # from functools import wraps
    # from copy import deepcopy
    # import pandas as pd
    # from pandas.core.base import PandasObject

    @wraps(func)
    def wrapper(*args, **kwargs):
        return func(*deepcopy(args), **deepcopy(kwargs))

    setattr(PandasObject, wrapper.__name__, wrapper)

    return wrapper


@as_method
def display_(DF):
    display(DF)
    return DF


@as_method
def d(num):
    pd.set_option("display.max_colwidth", num)


@as_method
def augment_uuid_fake(DF, id_name="uuid"):
    assert id_name not in list(
        DF.columns
    ), f"The '{id_name}' already existed in the column names."
    DF[id_name] = range(1, len(DF) + 1)
    DF[id_name] = DF[id_name].map(str).str.zfill(8) + "-0000-0000-0000-" + "0" * 12

    return DF


DATABASE_URL = # Here you get an error:) #"postgresql://postgres:PASSWORD@db.INSTANCE_NAME.supabase.co:5432/postgres"

engine = create_engine(DATABASE_URL)


def truncate(table):
    with engine.begin() as conn:
        conn.execute(text(f"TRUNCATE {table} CASCADE;"))


def insert_df(df, table):
    df.to_sql(table, engine, if_exists="append", index=False)


@as_method
def augment_uuid_for_unique_values_in_columns(DF, lst_column, id_):
    assert id_ not in list(
        DF.columns
    ), f"A Column with the name '{id_}' already exist in the DataFrame"

    DF_unique = DF[lst_column].drop_duplicates().augment_uuid_fake(id_)

    return DF.merge(DF_unique, on=lst_column, how="left")


# In[ ]:

with open("tree-information.json", "r") as f:
    data_dict = json.load(f)

df_daniel = pd.DataFrame(data_dict["trees"]).drop(columns=["images"])

for col in df_daniel.columns:
    df_daniel[col] = (
        df_daniel[col]
        .map(str)
        .str.replace("[", "", regex=False)
        .str.replace("]", "", regex=False)
        .str.replace("'", "", regex=False)
    )

df_daniel


# In[ ]:


lst_df = []

for category in data_dict["attributes"]:
    df_temp = (
        pd.DataFrame([data_dict["attributes"][category]])
        .T.reset_index()
        .rename(columns={"index": "attribute", 0: "description"})
        .assign(group=category)
    )

    lst_df.append(df_temp)

# %%

df_tree_attribute_groups = (
    pd.concat(lst_df)
    .augment_uuid_for_unique_values_in_columns(["group"], "tree_attribute_group_uuid")
    .display_()
)

# In[ ]:

lst_attributes = (
    df_daniel
    .drop(columns=["id", "name_trivial", "name_botanic", "strain"])
    .columns
)
# In[ ]:

df_melted = (
    df_daniel.melt("id", lst_attributes, var_name="attribute", value_name="value_")
    .sort_values("id")
    .reset_index(drop=True)
    .augment_uuid_fake("tree_attribute_uuid")
    .assign(tree_attribute_value_uuid=lambda df_: df_.tree_attribute_uuid)
    .display_()
)


# In[ ]:

df_tree_types = (
    df_daniel[["id", "name_trivial", "name_botanic", "strain"]]
    .augment_uuid_fake("tree_type_uuid")
    .display_()
)

# In[ ]:

df_big_table = (
    df_tree_types.merge(df_melted, on="id", how="right")
    .merge(df_tree_attribute_groups, on="attribute", how="left")
    .augment_uuid_fake()
)

assert len(df_big_table) == len(df_melted)
df_big_table


# In[ ]:

dct_df = {}

# In[ ]:
# 1

dct_df["tree_types"] = (
    df_big_table.assign(name=lambda df_: df_.name_trivial)[
        ["tree_type_uuid", "name", "name_trivial", "name_botanic", "strain"]
    ]
    .rename(columns={"tree_type_uuid": "uuid"})
    .drop_duplicates()
    .display_()
)

truncate("tree_types")

insert_df(dct_df["tree_types"], "tree_types")

# In[ ]:
# 2
dct_df["tree_attribute_groups"] = (
    df_big_table[["tree_attribute_group_uuid", "group"]]
    .rename(columns={"group": "name", "tree_attribute_group_uuid": "uuid"})
    .drop_duplicates()
    .display_()
)
truncate("tree_attribute_groups")

insert_df(dct_df["tree_attribute_groups"], "tree_attribute_groups")


# In[ ]:
# 3
dct_df["tree_attributes"] = (
    df_big_table[
        ["tree_attribute_uuid", "attribute", "description", "tree_attribute_group_uuid"]
    ]
    .rename(columns={"attribute": "name", "tree_attribute_uuid": "uuid"})
    .drop_duplicates()
    .display_()
)

truncate("tree_attributes")

insert_df(dct_df["tree_attributes"], "tree_attributes")


# In[ ]:
# 4

dct_df["tree_attribute_values"] = (
    df_big_table[["uuid", "value_", "tree_attribute_uuid"]]
    .rename(columns={"value_": "name"})
    .assign(name=lambda df_: df_.name.str[:100])
    .drop_duplicates()
    .display_()
)

truncate("tree_attribute_values")
insert_df(dct_df["tree_attribute_values"], "tree_attribute_values")


# In[ ]:
# 5

dct_df["tree_type_attribute_value_references"] = (
    df_big_table[
        ["uuid", "tree_type_uuid", "tree_attribute_uuid", "tree_attribute_value_uuid"]
    ]
    .drop_duplicates()
    .display_()
)

truncate("tree_type_attribute_value_references")
insert_df(
    dct_df["tree_type_attribute_value_references"],
    "tree_type_attribute_value_references",
)
