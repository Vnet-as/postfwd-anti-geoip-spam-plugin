# Useful Database Queries

To get statistic data about user logins, you can use database queries mentioned below.

1. Print mail accounts, total number of logins, total number of unique ip addresses and unique states for users who were logged in from more than 3 countries (Most useful for me):

```sql
SELECT sasl_username,
   SUM(login_count),
   COUNT(*) AS ip_address_count,
   COUNT(DISTINCT state_code) AS country_login_count
FROM postfwd_logins
GROUP BY sasl_username
HAVING country_login_count > 3;
```

2. Print users who are logged in from more than 1 country and write number of countries from which they were logged in:

```sql
SELECT sasl_username, COUNT(DISTINCT state_code) AS country_login_count
FROM postfwd_logins
GROUP BY sasl_username
HAVING country_login_count > 1;
```

3. Dump all IP addresses and login counts for users who were logged in from more than 1 country:

```sql
SELECT * FROM postfwd_logins
JOIN (
   SELECT sasl_username
   FROM postfwd_logins
   GROUP BY sasl_username
   HAVING COUNT(DISTINCT state_code) > 1
   ) AS users_logged_from_multiple_states
      ON postfwd_logins.sasl_username = users_logged_from_multiple_states.sasl_username
ORDER BY postfwd_logins.sasl_username;
```

4. Print summary of logins for user `<SASL_USERNAME>`:

```sql
SELECT SUM(login_count)
FROM postfwd_logins
WHERE sasl_username='<SASL_USERNAME>';
```

5. Print number of distinct login *state_codes* for user `<SASL_USERNAME>`:

```sql
SELECT COUNT(DISTINCT state_code)
FROM postfwd_logins
WHERE sasl_username='<SASL_USERNAME>';
```

6. Print number of distinct IP addresses for user `<SASL_USERNAME>`:

```sql
SELECT COUNT(DISTINCT ip_address)
FROM postfwd_logins
WHERE sasl_username='<SASL_USERNAME>';
```

7. Print number of IP addresses for each *state_code* for user `<SASL_USERNAME>`:

```sql
SELECT sasl_username, state_code, COUNT(state_code) AS country_login_count
FROM postfwd_logins
WHERE sasl_username='<SASL_USERNAME>'
GROUP BY state_code
ORDER BY country_login_count;
```
