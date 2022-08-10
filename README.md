# Db2 REST SDKs & Native CodeGen

Welcome to the repository holding the Db2 REST language-specific SDKs & language-native code generation utilities. The goal of this project is to make Db2 the simplest database for application developers to connect to for as many applications as possible.

[Db2 REST](https://www.ibm.com/docs/en/db2-for-zos/12?topic=db2-rest-services) is an incredibly flexible and easy-to-use REST interface to Db2, enabling you to run pre-defined arbitrary SQL services or even direct SQL queries. This repo provides SDKs that make connecting to Db2 REST itself even easier.

So easy, in fact, that the only documentation you'll need for each wrapper is a *single example* that demonstrates its use!

# Db2 REST Native CodeGen

The Native CodeGen utility will scrape Db2 REST for your service names and version, parameter names and types, and return value names and types, and auto-generate functions that use language-native functionality and types to make it *even easier* to interface with your Db2 REST services. Check out the Swift language code generator in the Swift folder to get started.
