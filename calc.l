%{
/*
This file is part of Reverse Notation Calc.

    Reverse Notation Calc is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Foobar is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

*/

#include "mystack.h"
int int_value;

typedef enum {
    LexNumber=1001,
    LexPlus,
    LexMinus,
    LexDiv,
    LexMult,
    LexEnd,
    LexUnknown,
    ArrayStart,
    ArrayDelimiter,
    ArrayEnd,
    ArrayConcatenation,
    ArrayInsertRight,
    ArrayInsertLeft
} LexType;

typedef enum {
    closed = 0,
    writing = 1
} stack_state;

my_stack arithmetic_stack;
my_stack array_stack;
my_stack arrays_count_stack;

stack_state array_stack_state;

int is_number_received;
int is_delimiter_received;
int is_array_received;

int end_file;


%}

%s SKIPERROR

digit     [0-9]
number    {digit}+

%%

{number}	{
		  int_value=atoi(yytext);
		  fprintf(stderr, "found %d\n", int_value);
		  return LexNumber; }
\+		{
		  fprintf(stderr, "plus\n");
		  return LexPlus; }
\-		{
		  fprintf(stderr, "minus\n");
		  return LexMinus; }
\/		{
		  fprintf(stderr, "div\n");
		  return LexDiv; }
\*		{
		  fprintf(stderr, "mult\n");
		  return LexMult; }
\+c     { fprintf(stderr, "arrayConcat\n");
          return ArrayConcatenation; }
\+l     {fprintf(stderr, "arrayInsertLeft\n");
          return ArrayInsertLeft; }
\+r     {fprintf(stderr, "arrayInsertRight\n");
          return ArrayInsertRight; }
\[      { 
          fprintf(stderr, "arrstart\n");
          return ArrayStart; }
,       { fprintf(stderr, "arrdelimiter\n");
          return ArrayDelimiter; }
\]      { fprintf(stderr, "arrend\n");
          return ArrayEnd; }
^[ \t]*\n	{
		  fprintf(stderr, "empty line\n");
		}
\n		{
		  fprintf(stderr, "CR\n");
		  return LexEnd; }
[ \t]		{ }
.		{ return LexUnknown; }

<SKIPERROR>[^\n]* {}
%%

void reset_flags_and_states();
int array_insert_left(my_stack* array_stack, int value);
int arrays_concatenate(my_stack* array_stack, my_stack* arrays_count_stack);
int array_increment_top(my_stack* stack);
void print_array_stack(my_stack* array_stack, my_stack* arrays_count_stack);

int process_command(int token)
{
    switch (token) {
    case LexNumber: {
        if (array_stack_state == writing) {
            my_stack_push(&array_stack, int_value);
            
            array_increment_top(&arrays_count_stack);
            
            is_number_received = 1;
            is_delimiter_received = 0;
        } else {
            my_stack_push(&arithmetic_stack, int_value);
            
            if (my_stack_is_full(&arithmetic_stack)) {
                return -1;
            }
            
            is_array_received = 0;
        }
        break; }
        
    case ArrayStart: {
        if (array_stack_state == writing) {
            return -1;
        }
        if (array_stack_state == closed) {
            array_stack_state = writing;
            
            my_stack_push(&arrays_count_stack, 0);
            
            is_number_received = 0; 
            is_delimiter_received = 0;
            is_array_received = 0;
        }
        break; }
        
    case ArrayDelimiter:
        if (array_stack_state == writing && is_number_received == 1) {
            is_number_received = 0;
            is_delimiter_received = 1;
        } else {
            return -1;
        }
        break;
        
    case ArrayEnd: {
        if (array_stack_state == writing) {
            int array_count = 0;
            my_stack_get_deep(&arrays_count_stack, 0, &array_count);
            if (array_count == 0) {
                return -1;
            }
            
            array_stack_state = closed;
            is_array_received = 1;
        } else {
            return -1;
        }
        if (is_number_received == 1 && is_delimiter_received == 0) {
            is_number_received = 0;
            is_delimiter_received = 0;
        } else {
            return -1;
        }
        break; }
        
    case ArrayConcatenation: {
        if (!is_array_received) {
            return -1;
        }
        if (my_stack_is_empty(&array_stack)) {
            return -1;
        }
        if (!arrays_concatenate(&array_stack, &arrays_count_stack)) {
            return -1;
        }
        is_array_received = 0;
        break; }
        
    case ArrayInsertLeft: {
        if (!is_array_received) {
            return -1;
        }
        if (my_stack_is_empty(&array_stack)) {
            return -1;
        }
        
        int left_value = my_stack_pull(&arithmetic_stack);
        
        if (array_insert_left(&array_stack, left_value)) {
            array_increment_top(&arrays_count_stack);
        } else {
            return -1;
        }
        is_array_received = 0;
        break;  }
        
    case ArrayInsertRight: {
        if (is_array_received) {
            return -1;
        }
        if (my_stack_is_empty(&array_stack)) {
            return -1;
        }
        
        int right_value = my_stack_pull(&arithmetic_stack);
        
        if (my_stack_is_empty(&array_stack)) {
            return -1;
        }
        my_stack_push(&array_stack, right_value);
        if (array_increment_top(&arrays_count_stack) != 1) {
            return -1;
        }
        // Reset receive array flag
        is_array_received = 0;
        break;  }
    
    case LexPlus: {
        if (my_stack_is_empty(&arithmetic_stack)) {
            return -1;
        }
        int a=my_stack_pull(&arithmetic_stack);

        if (my_stack_is_empty(&arithmetic_stack)) {
            return -1;
        }
        int b=my_stack_pull(&arithmetic_stack);

        my_stack_push(&arithmetic_stack, a+b);
        if (my_stack_is_full(&arithmetic_stack)) {
            return -1;
        }
        break;}
    case LexMinus: {
        if (my_stack_is_empty(&arithmetic_stack)) {
            return -1;
        }
        int a=my_stack_pull(&arithmetic_stack);

        if (my_stack_is_empty(&arithmetic_stack)) {
            return -1;
        }
        int b=my_stack_pull(&arithmetic_stack);

        my_stack_push(&arithmetic_stack, b-a);
        if (my_stack_is_full(&arithmetic_stack)) {
            return -1;
        }
        break;}
    case LexDiv: {
        if (my_stack_is_empty(&arithmetic_stack)) {
            return -1;
        }
        int a=my_stack_pull(&arithmetic_stack);

        if (my_stack_is_empty(&arithmetic_stack)) {
            return -1;
        }
        int b=my_stack_pull(&arithmetic_stack);

        my_stack_push(&arithmetic_stack, b/a);
        if (my_stack_is_full(&arithmetic_stack)) {
            return -1;
        }
        break;}
    case LexMult: {
        if (my_stack_is_empty(&arithmetic_stack)) {
            return -1;
        }
        int a=my_stack_pull(&arithmetic_stack);

        if (my_stack_is_empty(&arithmetic_stack)) {
            return -1;
        }
        int b=my_stack_pull(&arithmetic_stack);

        my_stack_push(&arithmetic_stack, b*a);
        if (my_stack_is_full(&arithmetic_stack)) {
            return -1;
        }
        break;}
    case LexEnd:
    case 0:
        return 0;
    case LexUnknown:
        return -1;

    }
    return 1;
}


void reset_flags_and_states()
{
    is_delimiter_received = 0;
    is_number_received = 0;
    is_array_received = 0;
    array_stack_state = closed;
}

int calc_line()
{
    int token = yylex();
    if (token == 0) {
        return 1;
    }

    while (1) {
        int cmd_res = process_command(token);
        if (cmd_res < 0 ) {
            reset_flags_and_states();
        }
        if (cmd_res == 0) {
            break;
        }
        else if (cmd_res == -1) {
            fprintf(stderr, "Syntax error\n");
            return 0;
        }
        token = yylex();
    }

    if (!my_stack_is_empty(&array_stack)) {
        print_array_stack(&array_stack, &arrays_count_stack);
    }
    
    int result = my_stack_pull(&arithmetic_stack);
    fprintf(yyout, "%d ", result);
    //
    if (!my_stack_is_empty(&arithmetic_stack)) {
        fprintf(stderr, "Stack not empty after calculation\n");
        return 0;
    }
    
    reset_flags_and_states();
    my_stack_clean(&array_stack);
    my_stack_clean(&arrays_count_stack);

    return 1;
}

void calc()
{
    while (!end_file) {
        fprintf(stderr, "parse line\n");
        if (calc_line() == 0) {
            printf("FAIL\n");
            BEGIN(SKIPERROR);
            yylex();
            BEGIN(INITIAL);
        }
        else {
            printf("OK\n");
        }
        fprintf(stderr, "line parsed\n");
    }
}

int array_insert_left(my_stack* array_stack, int value)
{
    if (my_stack_is_empty(array_stack)) {
        return -1;
    }
    
    my_stack temp_stack;
    my_stack_init(&temp_stack, 100);
    
    for (int i = 0, count = my_stack_get_count(array_stack); i < count; i++) {
        int stack_value = my_stack_pull(array_stack);
        my_stack_push(&temp_stack, stack_value);
    }
    
    my_stack_push(array_stack, value);
    
    for (int i = 0, count = my_stack_get_count(&temp_stack); i < count; i++) {
        int stack_value = my_stack_pull(&temp_stack);
        my_stack_push(array_stack, stack_value);
    }
    
    my_stack_done(&temp_stack);
    
    return 1;
}

int arrays_concatenate(my_stack* array_stack, my_stack* arrays_count_stack)
{
    if (my_stack_is_empty(arrays_count_stack)) {
        return -1;
    }
    int array_count_1 = my_stack_pull(arrays_count_stack);
    if (my_stack_is_empty(arrays_count_stack)) {
        return -1;
    }
    
    int array_count_2 = my_stack_pull(arrays_count_stack);
    
    int arrays_count_sum = array_count_1 + array_count_2;
    
    my_stack_push(arrays_count_stack, arrays_count_sum);
    
    return 1;
}

int array_increment_top(my_stack* stack)
{
    if (my_stack_is_empty(stack)) {
        return -1;
    }
    int array_count = my_stack_pull(stack);
    my_stack_push(stack, ++array_count);
    
    return 1;
}

void print_array_stack(my_stack* array_stack, my_stack* arrays_count_stack)
{
    fprintf(yyout, "%s", "array(");
    
    int value = my_stack_pull(arrays_count_stack);
    fprintf(yyout, "%d,", value);
    
    for (int i = 0, count = array_stack->count; i < count; i++) {
        int value = 0;
        
        my_stack_get_deep(array_stack, count - i - 1, &value);
        
        fprintf(yyout, "%d", value);
        
        if (i != count - 1) {
            fprintf(yyout, ",");
        }
    }
    
    fprintf(yyout, "%s \n", ")");
    
    my_stack_clean(array_stack);
}


int main(void)
{
    my_stack_init(&arithmetic_stack, 100);
    my_stack_init(&array_stack, 100);
    my_stack_init(&arrays_count_stack, 100);
    end_file = 0;

    calc();

    my_stack_done(&arithmetic_stack);
    my_stack_done(&array_stack);
    my_stack_done(&arrays_count_stack);
    return 0;
}

int yywrap(void)
{
    end_file = 1;
    return 1;
}